// The settings of the owner. They stay in the user defaults.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GLReplayGainMode) {
    GLReplayGainOff = 0,
    GLReplayGainTrack = 1,
    GLReplayGainAlbum = 2,
};

// Posted when a setting changes.
extern NSString *const GLSettingsDidChangeNotification;

@interface GLSettings : NSObject

+ (instancetype)shared;

// The lists sort "The Beatles" under B. Default: YES.
@property (nonatomic) BOOL ignoreArticles;
// Default: track.
@property (nonatomic) GLReplayGainMode replayGainMode;
// Relative folder paths under /var/mobile/Media that the scanner may index.
@property (nonatomic, copy) NSArray *musicFolders;

@end
