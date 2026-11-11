#import "GLMoreViewController.h"
#import "GLAlbumsViewController.h"
#import "GLArtistsViewController.h"
#import "GLFoldersViewController.h"
#import "GLPlaylistsViewController.h"
#import "GLSearchViewController.h"
#import "GLSettings.h"
#import "GLSettingsViewController.h"
#import "GLSongsViewController.h"
#import "GLTheme.h"
#import "GLUploadViewController.h"

@interface GLMoreViewController ()
@property (nonatomic, copy) NSArray *hiddenTabs;
@end

@implementation GLMoreViewController

- (instancetype)initWithHiddenTabs:(NSArray *)hiddenTabs {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"More";
        _hiddenTabs = [hiddenTabs copy] ?: @[];
    }
    return self;
}

- (instancetype)init {
    return [self initWithHiddenTabs:@[]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    self.tableView.rowHeight = 52;
    self.tableView.tableFooterView = [UIView new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged)
                                                 name:GLSettingsDidChangeNotification object:nil];
    [self settingsChanged];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)settingsChanged {
    NSMutableArray *hidden = [NSMutableArray array];
    for (NSString *item in [GLSettings shared].tabBarOrder) {
        if (![[GLSettings shared].tabBarItems containsObject:item]) [hidden addObject:item];
    }
    self.hiddenTabs = hidden;
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.hiddenTabs.count : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return self.hiddenTabs.count ? @"Library" : nil;
    return @"More";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
        cell.backgroundColor = GLBackgroundColor();
        cell.textLabel.font = GLFont(17);
        cell.textLabel.textColor = GLTextColor();
        cell.textLabel.backgroundColor = [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.section == 0) {
        cell.textLabel.text = [GLSettings titleForTabBarItem:self.hiddenTabs[indexPath.row]];
    } else {
        cell.textLabel.text = @[ @"Upload over Wi-Fi", @"Settings" ][indexPath.row];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *name = indexPath.section == 0 ? self.hiddenTabs[indexPath.row]
                                             : @[ @"upload", @"settings" ][indexPath.row];
    [self openScreen:name];
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

- (void)openScreen:(NSString *)name {
    UIViewController *screen = [self controllerForTab:name];
    if ([name isEqualToString:@"settings"]) screen = [GLSettingsViewController new];
    if ([name isEqualToString:@"upload"]) screen = [GLUploadViewController new];
    if (screen) [self.navigationController pushViewController:screen animated:YES];
}

@end
