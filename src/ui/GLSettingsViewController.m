#import "GLSettingsViewController.h"
#import "GLArtCache.h"
#import "GLFormat.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLLibraryUpdater.h"
#import "GLSettings.h"
#import "GLTextViewController.h"
#import "GLTheme.h"
#import "GLPaths.h"

typedef NS_ENUM(NSInteger, GLSettingsSection) {
    GLSectionSound,
    GLSectionNavigation,
    GLSectionLibrary,
    GLSectionAbout,
    GLSectionCount,
};

@interface GLMusicFoldersViewController : UITableViewController
@property (nonatomic, strong) NSArray *folders;
@end

@implementation GLMusicFoldersViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Music Folders";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    // Keep the default import folder available as a selectable root even on a
    // fresh install, before the owner has copied any music to the device.
    GLMusicDirectory();
    NSMutableArray *folders = [NSMutableArray array];
    NSDirectoryEnumerator *walk = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:GLMediaDirectory()]
        includingPropertiesForKeys:@[ NSURLIsDirectoryKey ] options:NSDirectoryEnumerationSkipsHiddenFiles
        errorHandler:nil];
    for (NSURL *url in walk) {
        NSNumber *directory = nil;
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:NULL];
        NSString *full = url.path.stringByStandardizingPath;
        NSString *prefix = [GLMediaDirectory().stringByStandardizingPath stringByAppendingString:@"/"];
        if (directory.boolValue && [full hasPrefix:prefix]) [folders addObject:[full substringFromIndex:prefix.length]];
    }
    self.folders = [folders sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.folders.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    NSString *folder = self.folders[indexPath.row];
    cell.textLabel.text = folder;
    cell.textLabel.font = GLFont(15);
    cell.textLabel.textColor = GLTextColor();
    cell.backgroundColor = GLSurfaceColor();
    for (NSString *root in [GLSettings shared].musicFolders) {
        if ([folder isEqualToString:root] || [folder hasPrefix:[root stringByAppendingString:@"/"]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *folder = self.folders[indexPath.row];
    NSMutableArray *selected = [[GLSettings shared].musicFolders mutableCopy];
    if ([selected containsObject:folder]) [selected removeObject:folder];
    else {
        for (NSString *root in selected) {
            if ([folder hasPrefix:[root stringByAppendingString:@"/"]]) return;
        }
        [selected addObject:folder];
    }
    // A parent selection already includes every child. Keep roots disjoint so
    // scanning and browsing never produce duplicate tracks.
    NSArray *ordered = [selected sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
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
    [GLSettings shared].musicFolders = roots;
    [tableView reloadData];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Choose folders under Media. A selected folder includes its subfolders.";
}

@end

@interface GLTabBarSettingsViewController : UITableViewController
@end

@implementation GLTabBarSettingsViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Tab Bar";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [GLSettings availableTabBarItems].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Choose up to five. Other destinations stay in More.";
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 48;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    NSString *item = [GLSettings availableTabBarItems][indexPath.row];
    cell.textLabel.text = [GLSettings titleForTabBarItem:item];
    cell.textLabel.font = GLFont(16);
    cell.textLabel.textColor = GLTextColor();
    cell.backgroundColor = GLSurfaceColor();
    cell.accessoryType = [[GLSettings shared].tabBarItems containsObject:item]
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *item = [GLSettings availableTabBarItems][indexPath.row];
    NSMutableArray *selected = [[GLSettings shared].tabBarItems mutableCopy];
    if ([selected containsObject:item]) {
        if (selected.count == 1) {
            [[[UIAlertView alloc] initWithTitle:@"Keep one tab"
                                        message:@"At least one destination must stay in the tab bar."
                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        [selected removeObject:item];
    } else {
        if (selected.count == 5) {
            [[[UIAlertView alloc] initWithTitle:@"Tab bar is full"
                                        message:@"Choose up to five destinations. Other destinations stay in More."
                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        [selected addObject:item];
    }
    [GLSettings shared].tabBarItems = selected;
    [tableView reloadData];
}

@end

@implementation GLSettingsViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Settings";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self.tableView selector:@selector(reloadData) name:GLScanDidStartNotification object:nil];
    [center addObserver:self.tableView selector:@selector(reloadData) name:GLScanDidEndNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return GLSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == GLSectionSound || section == GLSectionNavigation) return 1;
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[ @"Sound", @"Navigation", @"Library", @"About" ][section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 36)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = GLSecondaryTextColor();
    label.font = GLBoldFont(13);
    label.text = [@"     " stringByAppendingString:[self tableView:tableView titleForHeaderInSection:section].uppercaseString];
    return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = GLSurfaceColor();
    cell.textLabel.text = title;
    cell.textLabel.font = GLFont(16);
    cell.textLabel.textColor = GLTextColor();
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.font = GLFont(14);
    cell.detailTextLabel.textColor = GLSecondaryTextColor();
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    return cell;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title on:(BOOL)on action:(SEL)action {
    UITableViewCell *cell = [self cellWithTitle:title detail:nil];
    UISwitch *control = [UISwitch new];
    control.on = on;
    [control addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = control;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GLSettings *settings = [GLSettings shared];
    if (indexPath.section == GLSectionSound) {
        UITableViewCell *cell = [self cellWithTitle:@"ReplayGain" detail:nil];
        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:@[ @"Off", @"Track", @"Album" ]];
        control.segmentedControlStyle = UISegmentedControlStyleBar;
        control.frame = CGRectMake(0, 0, 170, 30);
        control.selectedSegmentIndex = settings.replayGainMode;
        [control addTarget:self action:@selector(replayGainChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    if (indexPath.section == GLSectionNavigation) {
        UITableViewCell *cell = [self cellWithTitle:@"Bottom bar"
                                             detail:[NSString stringWithFormat:@"%lu of 5",
                                                                              (unsigned long)settings.tabBarItems.count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if (indexPath.section == GLSectionLibrary) {
        switch (indexPath.row) {
            case 0:
                return [self switchCellWithTitle:@"Sort without \"The\"" on:settings.ignoreArticles
                                          action:@selector(toggleArticles:)];
            case 1: {
                UITableViewCell *cell = [self cellWithTitle:@"Music folders" detail:GLCountText((NSInteger)settings.musicFolders.count, @"folder")];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                return cell;
            }
            default: {
                GLLibraryUpdater *updater = [GLLibraryUpdater shared];
                NSString *detail = updater.scanning ? @"Scanning..." : GLCountText((NSInteger)[[GLLibrary shared] trackCount],
                                                                                    @"song");
                UITableViewCell *cell = [self cellWithTitle:@"Scan the library again" detail:detail];
                cell.textLabel.textColor = GLAccentColor();
                return cell;
            }
        }
    }
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    switch (indexPath.row) {
        case 0: {
            UITableViewCell *cell = [self cellWithTitle:@"Version" detail:version];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        case 1: {
            UITableViewCell *cell = [self cellWithTitle:@"Licences" detail:nil];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        default:
            return [self cellWithTitle:@"Groovelet on GitHub" detail:nil];
    }
}

- (void)replayGainChanged:(UISegmentedControl *)control {
    // The next track plays with the new gain.
    [GLSettings shared].replayGainMode = control.selectedSegmentIndex;
}

- (void)toggleArticles:(UISwitch *)control {
    [GLSettings shared].ignoreArticles = control.on;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == GLSectionNavigation) {
        [self.navigationController pushViewController:[GLTabBarSettingsViewController new] animated:YES];
    } else if (indexPath.section == GLSectionLibrary && indexPath.row == 1) {
        [self.navigationController pushViewController:[GLMusicFoldersViewController new] animated:YES];
    } else if (indexPath.section == GLSectionLibrary && indexPath.row == 2) {
        // This scan reads each file again, and makes the art again.
        [[GLArtCache shared] clear];
        [[GLImageLoader shared] clear];
        [[GLLibraryUpdater shared] scanAllFiles];
    } else if (indexPath.section == GLSectionAbout && indexPath.row == 1) {
        [self.navigationController pushViewController:[[GLTextViewController alloc] initWithTitle:@"Licences"
                                                                                             text:[self licences]]
                                             animated:YES];
    } else if (indexPath.section == GLSectionAbout && indexPath.row == 2) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/Stiven-Gjekaj/Groovelet"]];
    }
}

- (NSString *)licences {
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"Groovelet is free software under the MIT licence.\n\n"
                       @"It uses FFmpeg 7.1.1 under the LGPL 2.1. The app loads FFmpeg as the library "
                       @"libglffmpeg.dylib, which you can replace. The source of FFmpeg is at ffmpeg.org, and "
                       @"scripts/ffmpeg.sh in the repository of Groovelet builds it.\n\n"
                       @"It uses the Inter font under the SIL Open Font License 1.1.\n\n"];
    for (NSString *name in @[ @"Inter-OFL.txt", @"FFmpeg-LGPL-2.1.txt" ]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:name.stringByDeletingPathExtension ofType:@"txt"];
        NSString *body = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        if (body) [text appendFormat:@"=== %@ ===\n\n%@\n\n", name.stringByDeletingPathExtension, body];
    }
    return text;
}

@end
