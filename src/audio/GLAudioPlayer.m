#import "GLAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "GLDecoders.h"
#import "GLRenderer.h"
#import "GLReplayGain.h"
#import <AudioToolbox/AudioSession.h>

// 4 buffers of 8192 frames hold 0.74 seconds of sound. A larger buffer
// wakes the CPU less often. A seek fills them again at once.
enum { GLBufferCount = 4, GLBufferFrames = 8192 };

static NSValue *GLItemKey(id item) {
    return [NSValue valueWithNonretainedObject:item];
}

@interface GLAudioPlayer () <AVAudioSessionDelegate>
@property (nonatomic) AudioQueueRef queue;
@property (nonatomic, strong) GLRenderer *renderer;
@property (nonatomic, assign) dispatch_queue_t openQueue;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL playing;
@property (nonatomic, strong) id currentItem;
@property (nonatomic) double currentTime;
@property (nonatomic) double duration;
@property (nonatomic, strong) NSMutableDictionary *durations;
@property (nonatomic, strong) NSMutableDictionary *paths;
@property (nonatomic, strong) NSMutableDictionary *gains;
@property (nonatomic) BOOL interrupted;
@property (nonatomic) NSUInteger nextToken;
// The start frame of the play that the clock last saw.
@property (nonatomic) int64_t currentStartFrame;
// The buffers that came back with no sound to fill, at the end of the
// stream. A next track that comes late fills them again.
@property (nonatomic, strong) NSMutableArray *idleBuffers;
- (void)routeWasRemoved;
@end

@interface GLAudioPlayer (Fill)
- (void)fillBuffer:(AudioQueueBufferRef)buffer queue:(AudioQueueRef)queue;
@end

static void GLFillBuffer(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    // The thread of the AudioQueue has no autorelease pool.
    @autoreleasepool {
        [(__bridge GLAudioPlayer *)context fillBuffer:buffer queue:queue];
    }
}

// iOS 5 reports route changes through Audio Session Services.
static void GLRouteChanged(void *context, AudioSessionPropertyID property,
                           UInt32 size, const void *value) {
    if (property != kAudioSessionProperty_AudioRouteChange || !value) return;
    CFDictionaryRef changes = (CFDictionaryRef)value;
    CFNumberRef reason = (CFNumberRef)CFDictionaryGetValue(
        changes, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
    SInt32 reasonValue = 0;
    if (reason && CFNumberGetValue(reason, kCFNumberSInt32Type, &reasonValue) &&
        reasonValue == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
        GLAudioPlayer *player = (__bridge GLAudioPlayer *)context;
        dispatch_async(dispatch_get_main_queue(), ^{ [player routeWasRemoved]; });
    }
}

@implementation GLAudioPlayer

- (instancetype)init {
    if ((self = [super init])) {
        _renderer = [GLRenderer new];
        _openQueue = dispatch_queue_create("GLAudioPlayer.open", DISPATCH_QUEUE_SERIAL);
        _durations = [NSMutableDictionary dictionary];
        _paths = [NSMutableDictionary dictionary];
        _gains = [NSMutableDictionary dictionary];
        _idleBuffers = [NSMutableArray array];
        _volume = 1;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:NULL];
        // These delegate and property-listener APIs also work on iOS 5.1.
        session.delegate = self;
        AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,
                                        GLRouteChanged, (__bridge void *)self);
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange,
                                                    GLRouteChanged, (__bridge void *)self);
    [AVAudioSession sharedInstance].delegate = nil;
    [_timer invalidate];
    if (_queue) AudioQueueDispose(_queue, true);
#if !defined(OS_OBJECT_USE_OBJC) || !OS_OBJECT_USE_OBJC
    if (_openQueue) dispatch_release(_openQueue);
#endif
}

#pragma mark The queue

// Called on the thread of the AudioQueue.
- (void)fillBuffer:(AudioQueueBufferRef)buffer queue:(AudioQueueRef)queue {
    NSUInteger frames = [self.renderer renderInto:buffer->mAudioData frames:GLBufferFrames];
    if (frames == 0) {
        // The end. The buffer stays out of the queue until a next track comes.
        @synchronized (self.idleBuffers) {
            [self.idleBuffers addObject:[NSValue valueWithPointer:buffer]];
        }
        return;
    }
    buffer->mAudioDataByteSize = (UInt32)(frames * GLOutputChannels * sizeof(int16_t));
    AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}

// Fills the idle buffers again, after a next track came late.
- (void)refillIdleBuffers {
    NSArray *buffers;
    @synchronized (self.idleBuffers) {
        buffers = [self.idleBuffers copy];
        [self.idleBuffers removeAllObjects];
    }
    for (NSValue *value in buffers) [self fillBuffer:value.pointerValue queue:self.queue];
}

- (void)disposeQueue {
    if (!self.queue) return;
    AudioQueueDispose(self.queue, true);
    self.queue = NULL;
}

// Makes a new queue and fills its buffers from the renderer. A new queue
// counts its frames from 0, as the renderer does after startItem:.
- (BOOL)makeQueue {
    [self disposeQueue];
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = GLOutputRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mChannelsPerFrame = GLOutputChannels;
    format.mBitsPerChannel = 16;
    format.mBytesPerFrame = 2 * GLOutputChannels;
    format.mFramesPerPacket = 1;
    format.mBytesPerPacket = format.mBytesPerFrame;
    AudioQueueRef queue = NULL;
    // The queue keeps a plain pointer to the player. The player disposes of
    // the queue before it goes away.
    if (AudioQueueNewOutput(&format, GLFillBuffer, (__bridge void *)self, NULL, NULL, 0, &queue) != noErr) {
        return NO;
    }
    AudioQueueSetParameter(queue, kAudioQueueParam_Volume, self.volume);
    @synchronized (self.idleBuffers) {
        [self.idleBuffers removeAllObjects];
    }
    self.queue = queue;
    for (int i = 0; i < GLBufferCount; i++) {
        AudioQueueBufferRef buffer = NULL;
        if (AudioQueueAllocateBuffer(queue, GLBufferFrames * format.mBytesPerFrame, &buffer) != noErr) break;
        [self fillBuffer:buffer queue:queue];
    }
    return YES;
}

- (int64_t)playedFrame {
    if (!self.queue) return -1;
    AudioTimeStamp time = {0};
    if (AudioQueueGetCurrentTime(self.queue, NULL, &time, NULL) != noErr) return -1;
    if (!(time.mFlags & kAudioTimeStampSampleTimeValid)) return -1;
    return (int64_t)time.mSampleTime;
}

- (void)setVolume:(float)volume {
    _volume = volume;
    if (self.queue) AudioQueueSetParameter(self.queue, kAudioQueueParam_Volume, volume);
}

#pragma mark Play

// Opens the decoder of a file, with the gain of the item.
static id<GLDecoder> GLOpenWithGain(NSString *path, double gain) {
    return [GLGainDecoder decoderWithDecoder:GLOpenDecoder(path, NULL) factor:gain];
}

- (BOOL)playItem:(id)item path:(NSString *)path gain:(double)gain atTime:(double)seconds paused:(BOOL)paused {
    id<GLDecoder> decoder = GLOpenWithGain(path, gain);
    if (!decoder) return NO;
    [self.durations removeAllObjects];
    [self.paths removeAllObjects];
    [self.gains removeAllObjects];
    [self.durations setObject:@(decoder.duration) forKey:GLItemKey(item)];
    [self.paths setObject:path forKey:GLItemKey(item)];
    [self.gains setObject:@(gain) forKey:GLItemKey(item)];
    self.nextToken++;
    [self.renderer setNextItem:nil decoder:nil];
    [self.renderer startItem:item decoder:decoder atTime:seconds];
    self.currentItem = item;
    self.currentStartFrame = 0;
    self.currentTime = seconds;
    self.duration = decoder.duration;
    if (![self makeQueue]) return NO;
    [self startTimer];
    if (paused) {
        self.playing = NO;
    } else {
        [self startQueue];
    }
    [self.delegate audioPlayer:self didStartItem:item];
    return YES;
}

- (void)startQueue {
    [[AVAudioSession sharedInstance] setActive:YES error:NULL];
    self.playing = AudioQueueStart(self.queue, NULL) == noErr;
}

- (void)setNextItem:(id)item path:(NSString *)path gain:(double)gain {
    NSUInteger token = ++self.nextToken;
    [self.renderer setNextItem:nil decoder:nil];
    if (!item) return;
    // Open the file away from the main thread. A newer call wins.
    dispatch_async(self.openQueue, ^{
        id<GLDecoder> decoder = GLOpenWithGain(path, gain);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token != self.nextToken || !decoder) return;
            [self.durations setObject:@(decoder.duration) forKey:GLItemKey(item)];
            [self.paths setObject:path forKey:GLItemKey(item)];
            [self.gains setObject:@(gain) forKey:GLItemKey(item)];
            [self.renderer setNextItem:item decoder:decoder];
            if (self.queue) [self refillIdleBuffers];
        });
    });
}

- (void)pause {
    if (!self.queue || !self.playing) return;
    [self updatePosition];
    AudioQueuePause(self.queue);
    self.playing = NO;
}

- (void)resume {
    if (!self.queue || self.playing) return;
    [self startQueue];
}

- (void)seekToTime:(double)seconds {
    if (!self.currentItem) return;
    BOOL wasPlaying = self.playing;
    seconds = MAX(0, MIN(seconds, self.duration));
    // A new queue starts its count of frames from 0, and the renderer starts
    // its timeline again. The next item stays.
    [self disposeQueue];
    id reading = self.renderer.currentItem;
    if (reading != self.currentItem) {
        // The renderer reads the next track already. Open the current track
        // again, and make the track that the renderer read the next one.
        id<GLDecoder> decoder = GLOpenWithGain([self.paths objectForKey:GLItemKey(self.currentItem)],
                                               [[self.gains objectForKey:GLItemKey(self.currentItem)] doubleValue]);
        if (!decoder) return;
        [self.renderer startItem:self.currentItem decoder:decoder atTime:seconds];
        if (reading) {
            [self setNextItem:reading path:[self.paths objectForKey:GLItemKey(reading)]
                         gain:[[self.gains objectForKey:GLItemKey(reading)] doubleValue]];
        }
    } else if (![self.renderer restartAtTime:seconds]) {
        return;
    }
    self.currentTime = seconds;
    self.currentStartFrame = 0;
    self.playing = NO;
    if (![self makeQueue]) return;
    if (wasPlaying) [self startQueue];
}

- (void)stop {
    [self disposeQueue];
    [self.timer invalidate];
    self.timer = nil;
    [self.renderer clear];
    self.playing = NO;
    self.currentItem = nil;
    self.currentTime = 0;
    self.duration = 0;
}

#pragma mark The clock

- (void)startTimer {
    if (self.timer) return;
    self.timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)updatePosition {
    int64_t frame = [self playedFrame];
    if (frame < 0) return;
    GLRendererPosition *position = [self.renderer positionAtFrame:frame];
    if (position.item && (position.item != self.currentItem || position.startFrame != self.currentStartFrame)) {
        self.currentStartFrame = position.startFrame;
        self.currentItem = position.item;
        self.duration = [[self.durations objectForKey:GLItemKey(position.item)] doubleValue];
        self.currentTime = position.time;
        [self.delegate audioPlayer:self didStartItem:position.item];
    } else if (position.item) {
        self.currentTime = position.time;
    }
}

- (void)tick {
    if (!self.playing) return;
    [self updatePosition];
    int64_t end = self.renderer.endFrame;
    int64_t frame = [self playedFrame];
    if (end >= 0 && frame >= end) {
        [self stop];
        [self.delegate audioPlayerDidFinish:self];
    }
}

#pragma mark The audio session

- (void)beginInterruption {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.playing) return;
        [self pause];
        self.interrupted = YES;
        [self.delegate audioPlayerDidChangeState:self];
    });
}

- (void)endInterruptionWithFlags:(NSUInteger)flags {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL resume = self.interrupted && (flags & AVAudioSessionInterruptionFlags_ShouldResume);
        self.interrupted = NO;
        if (resume) [self resume];
        [self.delegate audioPlayerDidChangeState:self];
    });
}

- (void)routeWasRemoved {
    // The headphones came out. Do not play from the speaker.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.playing) return;
        [self pause];
        [self.delegate audioPlayerDidChangeState:self];
    });
}

@end
