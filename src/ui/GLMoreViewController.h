// The More tab: Playlists, Upload, and Settings.

#import <UIKit/UIKit.h>

@interface GLMoreViewController : UITableViewController
// Opens the screen with this name: "playlists", "upload", or "settings".
- (void)openScreen:(NSString *)name;
@end
