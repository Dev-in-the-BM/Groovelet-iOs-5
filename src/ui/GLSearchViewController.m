#import "GLSearchViewController.h"

@implementation GLSearchViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Search";
        self.tabBarItem.title = @"Search";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-search.png"];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showSearchField];
}

- (NSString *)emptyText {
    return @"Search by song, artist, or album.";
}

@end
