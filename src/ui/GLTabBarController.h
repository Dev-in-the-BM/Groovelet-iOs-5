// The tabs of the app: Artists, Albums, Songs, Folders, and More. Playlists,
// Upload, and Settings live in More. The mini player sits above the tab bar.

#import <UIKit/UIKit.h>

@interface GLTabBarController : UITabBarController
// Opens the player screen.
- (void)showPlayer;
// Opens the player screen and the queue over it.
- (void)showQueue;
@end
