// User-selected library destinations appear in the tab bar (up to five).
// Secondary destinations and app tools are reached from each navigation bar.
// The mini player sits above the tab bar.

#import <UIKit/UIKit.h>

@interface GLTabBarController : UITabBarController
// Opens the player screen.
- (void)showPlayer;
// Opens the player screen and the queue over it.
- (void)showQueue;
@end
