#import "GLAppDelegate.h"
#import "GLAlbumViewController.h"
#import "GLAlbumsViewController.h"
#import "GLArtistsViewController.h"
#import "GLDebug.h"
#import "GLFoldersViewController.h"
#import "GLDecoders.h"
#import "GLImport.h"
#import "GLLibrary.h"
#import "GLLibraryUpdater.h"
#import "GLLink.h"
#import "GLLog.h"
#import "GLMoreViewController.h"
#import "GLNavigationController.h"
#import "GLPaths.h"
#import "GLPlayback.h"
#import "GLPlaylistViewController.h"
#import "GLPlaylistsViewController.h"
#import "GLSearchViewController.h"
#import "GLSettings.h"
#import "GLSongsViewController.h"
#import "GLTabBarController.h"
#import "GLTheme.h"

@interface GLAppDelegate ()
@property (nonatomic, strong) GLTabBarController *tabs;
@property (nonatomic, copy) NSArray *scannedMusicFolders;
@property (nonatomic, copy) NSArray *scannedTabBarItems;
@property (nonatomic, copy) NSDictionary *tabNavigations;
@end

@implementation GLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    GLLog(@"launch");
    GLApplyTheme();
    [GLLibrary shared].ignoreArticles = [GLSettings shared].ignoreArticles;
    self.scannedMusicFolders = [GLSettings shared].musicFolders;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged)
                                                 name:GLSettingsDidChangeNotification object:nil];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = GLBackgroundColor();
    self.tabs = [GLTabBarController new];
    self.tabNavigations = @{};
    [self rebuildTabs];
    self.window.rootViewController = self.tabs;
    [self.window makeKeyAndVisible];

    [[GLPlayback shared] restore];
    [application beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[GLPlayback shared] save];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[GLPlayback shared] save];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // New files can come over USB while the app is away.
    [[GLLibraryUpdater shared] scan];
}

- (void)settingsChanged {
    NSArray *tabBarItems = [GLSettings shared].tabBarItems;
    if (![self.scannedTabBarItems isEqualToArray:tabBarItems]) [self rebuildTabs];

    NSArray *folders = [GLSettings shared].musicFolders;
    if (![self.scannedMusicFolders isEqualToArray:folders]) {
        self.scannedMusicFolders = folders;
        [[GLLibrary shared] postChange];
        [[GLLibraryUpdater shared] scan];
    }
    if ([GLLibrary shared].ignoreArticles != [GLSettings shared].ignoreArticles) {
        [GLLibrary shared].ignoreArticles = [GLSettings shared].ignoreArticles;
        [[GLLibrary shared] postChange];
    }
}

- (UIViewController *)controllerForTab:(NSString *)item {
    if ([item isEqualToString:@"artists"]) return [GLArtistsViewController new];
    if ([item isEqualToString:@"albums"]) return [GLAlbumsViewController new];
    if ([item isEqualToString:@"songs"]) return [GLSongsViewController new];
    if ([item isEqualToString:@"folders"]) return [[GLFoldersViewController alloc] initWithFolder:@""];
    if ([item isEqualToString:@"playlists"]) return [GLPlaylistsViewController new];
    if ([item isEqualToString:@"search"]) return [GLSearchViewController new];
    return nil;
}

- (void)rebuildTabs {
    NSString *selectedItem = nil;
    UIViewController *selected = self.tabs.selectedViewController;
    for (NSString *item in self.tabNavigations) {
        if (self.tabNavigations[item] == selected) { selectedItem = item; break; }
    }

    NSArray *items = [GLSettings shared].tabBarItems;
    NSMutableDictionary *navigationsByItem = [NSMutableDictionary dictionary];
    NSMutableArray *navigations = [NSMutableArray array];
    for (NSString *item in items) {
        UINavigationController *navigation = self.tabNavigations[item];
        if (!navigation) {
            UIViewController *root = [self controllerForTab:item];
            root.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"More"
                style:UIBarButtonItemStyleBordered target:self action:@selector(showMore)];
            navigation = [[GLNavigationController alloc] initWithRootViewController:root];
        }
        navigationsByItem[item] = navigation;
        [navigations addObject:navigation];
    }
    self.scannedTabBarItems = items;
    self.tabNavigations = navigationsByItem;
    self.tabs.viewControllers = navigations;
    NSUInteger index = [items indexOfObject:selectedItem ?: @"songs"];
    self.tabs.selectedIndex = index == NSNotFound ? 0 : index;
}

- (NSArray *)hiddenTabItems {
    NSMutableArray *hidden = [NSMutableArray array];
    for (NSString *item in [GLSettings availableTabBarItems]) {
        if (![[GLSettings shared].tabBarItems containsObject:item]) [hidden addObject:item];
    }
    return hidden;
}

- (GLMoreViewController *)pushMoreWithScreen:(NSString *)screenName animated:(BOOL)animated {
    UINavigationController *navigation = (UINavigationController *)self.tabs.selectedViewController;
    GLMoreViewController *more = [[GLMoreViewController alloc] initWithHiddenTabs:[self hiddenTabItems]];
    [navigation pushViewController:more animated:animated];
    if (screenName) [more openScreen:screenName];
    return more;
}

- (void)showMore {
    UINavigationController *navigation = (UINavigationController *)self.tabs.selectedViewController;
    if ([navigation.topViewController isKindOfClass:[GLMoreViewController class]]) return;
    [self pushMoreWithScreen:nil animated:YES];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    GLLog(@"link %@", url);
    if (url.isFileURL) return [self importFile:url];
    if (GLHandleDebugLink(url, self.tabs)) return YES;
    GLLink *link = GLParseLink(url);
    if (!link) return NO;
    GLPlayback *playback = [GLPlayback shared];
    switch (link.kind) {
        case GLLinkPlay: [self playFolderOfPath:link.path atTime:link.time]; break;
        case GLLinkPause: [playback pause]; break;
        case GLLinkResume: [playback play]; break;
        case GLLinkNext: [playback next]; break;
        case GLLinkPrevious: [playback previous]; break;
        case GLLinkSeek: [playback seekToTime:link.time]; break;
        case GLLinkOpen: [self openScreen:link.name path:link.path]; break;
        case GLLinkSleep:
            if ([link.name isEqualToString:@"end"]) [playback sleepAtEndOfCurrentTrack];
            else [playback sleepAfterSeconds:link.time];
            break;
    }
    return YES;
}

// Another app opened a file in Groovelet. iOS put it in Documents/Inbox.
- (BOOL)importFile:(NSURL *)url {
    NSError *error = nil;
    NSString *path = GLImportFile(url.path, GLMusicDirectory(), &error);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:path ? @"Added" : @"Not added"
                                                    message:path ? [NSString stringWithFormat:@"%@ is in Imported.",
                                                                       path.lastPathComponent]
                                                                 : error.localizedDescription
                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    if (path) [[GLLibraryUpdater shared] scan];
    return path != nil;
}

// Opens a visible tab, a hidden destination from More, or a detail screen.
- (void)openScreen:(NSString *)name path:(NSString *)path {
    [self.tabs dismissViewControllerAnimated:NO completion:nil];
    NSArray *tabs = [GLSettings shared].tabBarItems;
    NSUInteger tab = [tabs indexOfObject:name];
    if (tab != NSNotFound) {
        self.tabs.selectedIndex = tab;
        [(UINavigationController *)self.tabs.selectedViewController popToRootViewControllerAnimated:NO];
        return;
    }
    if ([[GLSettings availableTabBarItems] containsObject:name]) {
        [self pushMoreWithScreen:name animated:NO];
        return;
    }
    if ([name isEqualToString:@"more"]) {
        [(UINavigationController *)self.tabs.selectedViewController popToRootViewControllerAnimated:NO];
        [self pushMoreWithScreen:nil animated:NO];
        return;
    }
    if ([name isEqualToString:@"player"]) {
        [self.tabs showPlayer];
        return;
    }
    if ([name isEqualToString:@"queue"]) {
        [self.tabs showQueue];
        return;
    }
    if ([@[ @"upload", @"settings" ] containsObject:name]) {
        [(UINavigationController *)self.tabs.selectedViewController popToRootViewControllerAnimated:NO];
        [self pushMoreWithScreen:name animated:NO];
        return;
    }
    if ([name isEqualToString:@"playlist"] && path) {
        GLPlaylist *playlist = [GLPlaylist new];
        playlist.kind = GLPlaylistFile;
        playlist.path = path;
        playlist.name = path.lastPathComponent.stringByDeletingPathExtension;
        NSUInteger playlistTab = [[GLSettings shared].tabBarItems indexOfObject:@"playlists"];
        if (playlistTab != NSNotFound) self.tabs.selectedIndex = playlistTab;
        UINavigationController *navigation = (UINavigationController *)self.tabs.selectedViewController;
        [navigation popToRootViewControllerAnimated:NO];
        if (playlistTab == NSNotFound) [self pushMoreWithScreen:@"playlists" animated:NO];
        navigation = (UINavigationController *)self.tabs.selectedViewController;
        [navigation pushViewController:[[GLPlaylistViewController alloc] initWithPlaylist:playlist] animated:NO];
        return;
    }
    if ([name isEqualToString:@"album"] && path) {
        GLTrack *track = [[GLLibrary shared] trackWithPath:path];
        GLAlbum *album = nil;
        for (GLAlbum *candidate in [[GLLibrary shared] albumsOfArtist:track.displayAlbumArtist]) {
            if ([candidate.key isEqualToString:track.albumKey]) album = candidate;
        }
        if (!album) return;
        NSUInteger albumTab = [[GLSettings shared].tabBarItems indexOfObject:@"albums"];
        if (albumTab != NSNotFound) self.tabs.selectedIndex = albumTab;
        UINavigationController *navigation = (UINavigationController *)self.tabs.selectedViewController;
        [navigation popToRootViewControllerAnimated:NO];
        if (albumTab == NSNotFound) [self pushMoreWithScreen:@"albums" animated:NO];
        navigation = (UINavigationController *)self.tabs.selectedViewController;
        [navigation pushViewController:[[GLAlbumViewController alloc] initWithAlbum:album] animated:NO];
    }
}

// Plays the audio files of the folder of `path`, from `path`.
- (void)playFolderOfPath:(NSString *)path atTime:(double)seconds {
    NSString *folder = path.stringByDeletingLastPathComponent;
    NSArray *tracks = [[GLLibrary shared] contentOfFolder:folder].tracks;
    if (!tracks.count) {
        // The scan has not seen the folder yet. Use the files on disk.
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:GLAbsolutePath(folder) error:NULL];
        NSMutableArray *found = [NSMutableArray array];
        for (NSString *name in [names sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
            if (GLIsAudioPath(name)) [found addObject:[GLTrack trackWithPath:[folder stringByAppendingPathComponent:name]]];
        }
        tracks = found;
    }
    NSUInteger start = [[tracks valueForKey:@"path"] indexOfObject:path];
    if (start == NSNotFound) return;
    [[GLPlayback shared] playTracks:tracks startAtIndex:start];
    if (seconds > 0) [[GLPlayback shared] seekToTime:seconds];
}

// The app delegate is the last responder, so the remote control events
// that no view takes come here.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [[GLPlayback shared] handleRemoteControlEvent:event];
}

@end
