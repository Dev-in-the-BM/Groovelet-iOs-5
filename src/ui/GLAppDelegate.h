// The delegate of the app. It makes the window and the first screen.

#import <UIKit/UIKit.h>

@interface GLAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
