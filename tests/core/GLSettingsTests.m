// Tests of the settings. The test program has its own user defaults.

#import "GLSettings.h"
#import "GLTest.h"

GL_TEST(test_settings_have_their_defaults_and_keep_a_change) {
    GLSettings *settings = [GLSettings shared];
    for (NSString *key in @[ @"ignoreArticles", @"replayGainMode", @"musicFolders", @"tabBarItems" ]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    GL_EXPECT(settings.ignoreArticles);
    GL_EQUAL_INT(settings.replayGainMode, GLReplayGainTrack);
    GL_EQUAL(settings.musicFolders, (@[ @"Groovelet" ]));
    GL_EQUAL(settings.tabBarItems, (@[ @"artists", @"albums", @"songs", @"folders", @"playlists" ]));
    __block int posts = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:GLSettingsDidChangeNotification object:nil
                                                                     queue:nil usingBlock:^(NSNotification *note) {
                                                                         posts++;
                                                                     }];
    settings.replayGainMode = GLReplayGainAlbum;
    settings.ignoreArticles = NO;
    GL_EQUAL_INT(settings.replayGainMode, GLReplayGainAlbum);
    GL_EXPECT(!settings.ignoreArticles);
    settings.musicFolders = @[ @"Music", @"Music/Albums", @"../outside", @"/private" ];
    GL_EQUAL(settings.musicFolders, (@[ @"Music" ]));
    settings.tabBarItems = @[ @"search", @"artists", @"unknown" ];
    GL_EQUAL(settings.tabBarItems, (@[ @"artists", @"search" ]));
    settings.tabBarItems = @[ @"search", @"folders", @"songs", @"albums", @"artists", @"playlists" ];
    GL_EQUAL_INT(settings.tabBarItems.count, 5);
    GL_EQUAL_INT(posts, 5);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    for (NSString *key in @[ @"ignoreArticles", @"replayGainMode", @"musicFolders", @"tabBarItems" ]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
}
