#import "GLSettings.h"

NSString *const GLSettingsDidChangeNotification = @"GLSettingsDidChange";

static NSString *const GLIgnoreArticlesKey = @"ignoreArticles";
static NSString *const GLReplayGainKey = @"replayGainMode";
static NSString *const GLMusicFoldersKey = @"musicFolders";
static NSString *const GLTabBarItemsKey = @"tabBarItems";

static NSArray *GLAvailableTabBarItems(void) {
    return @[ @"artists", @"albums", @"songs", @"folders", @"playlists", @"search" ];
}

static NSArray *GLDefaultTabBarItems(void) {
    return @[ @"artists", @"albums", @"songs", @"folders", @"playlists" ];
}

@implementation GLSettings

+ (instancetype)shared {
    static GLSettings *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [GLSettings new];
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            GLIgnoreArticlesKey: @YES, GLReplayGainKey: @(GLReplayGainTrack),
            GLMusicFoldersKey: @[ @"Groovelet" ], GLTabBarItemsKey: GLDefaultTabBarItems(),
        }];
    });
    return shared;
}

+ (NSArray *)availableTabBarItems { return GLAvailableTabBarItems(); }

+ (NSArray *)defaultTabBarItems { return GLDefaultTabBarItems(); }

+ (NSString *)titleForTabBarItem:(NSString *)item {
    NSDictionary *titles = @{
        @"artists": @"Artists", @"albums": @"Albums", @"songs": @"Songs",
        @"folders": @"Folders", @"playlists": @"Playlists", @"search": @"Search",
    };
    return titles[item];
}

- (void)setValue:(id)value forSetting:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsDidChangeNotification object:self];
}

- (BOOL)ignoreArticles {
    return [[NSUserDefaults standardUserDefaults] boolForKey:GLIgnoreArticlesKey];
}

- (void)setIgnoreArticles:(BOOL)ignoreArticles {
    [self setValue:@(ignoreArticles) forSetting:GLIgnoreArticlesKey];
}

- (GLReplayGainMode)replayGainMode {
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:GLReplayGainKey];
    return mode >= GLReplayGainOff && mode <= GLReplayGainAlbum ? (GLReplayGainMode)mode : GLReplayGainTrack;
}

- (void)setReplayGainMode:(GLReplayGainMode)replayGainMode {
    [self setValue:@(replayGainMode) forSetting:GLReplayGainKey];
}

- (NSArray *)musicFolders {
    NSArray *folders = [[NSUserDefaults standardUserDefaults] arrayForKey:GLMusicFoldersKey];
    return folders ?: @[ @"Groovelet" ];
}

- (void)setMusicFolders:(NSArray *)musicFolders {
    NSMutableArray *safe = [NSMutableArray array];
    for (NSString *folder in musicFolders) {
        if (![folder isKindOfClass:[NSString class]]) continue;
        NSString *path = folder.stringByStandardizingPath;
        if (!path.length || [path isEqualToString:@"."] || [path hasPrefix:@"/"] ||
            [path isEqualToString:@".."] || [path hasPrefix:@"../"] ||
            [path rangeOfString:@"/../"].location != NSNotFound ||
            [path hasSuffix:@"/.."] || [safe containsObject:path]) continue;
        [safe addObject:path];
    }
    NSArray *ordered = [safe sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        if (a.length < b.length) return NSOrderedAscending;
        if (a.length > b.length) return NSOrderedDescending;
        return [a compare:b];
    }];
    NSMutableArray *roots = [NSMutableArray array];
    for (NSString *candidate in ordered) {
        BOOL covered = NO;
        for (NSString *root in roots) if ([candidate hasPrefix:[root stringByAppendingString:@"/"]]) { covered = YES; break; }
        if (!covered) [roots addObject:candidate];
    }
    [self setValue:roots forSetting:GLMusicFoldersKey];
}

- (NSArray *)tabBarItems {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:GLTabBarItemsKey];
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *item in GLAvailableTabBarItems()) {
        if ([stored containsObject:item] && items.count < 5) [items addObject:item];
    }
    return items.count ? items : GLDefaultTabBarItems();
}

- (void)setTabBarItems:(NSArray *)tabBarItems {
    NSMutableArray *safe = [NSMutableArray array];
    for (NSString *item in GLAvailableTabBarItems()) {
        if ([tabBarItems containsObject:item] && safe.count < 5) [safe addObject:item];
    }
    if (!safe.count) safe = [GLDefaultTabBarItems() mutableCopy];
    [self setValue:safe forSetting:GLTabBarItemsKey];
}

@end
