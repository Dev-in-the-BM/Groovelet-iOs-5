// Secondary library destinations and app tools, opened from the top bar.

#import <UIKit/UIKit.h>

@interface GLMoreViewController : UITableViewController
- (instancetype)initWithHiddenTabs:(NSArray *)hiddenTabs;
// Opens a library destination or tool from the More list.
- (void)openScreen:(NSString *)name;
@end
