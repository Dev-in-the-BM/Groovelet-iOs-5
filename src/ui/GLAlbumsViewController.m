#import "GLAlbumsViewController.h"
#import "GLAlbumViewController.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLTheme.h"

// A row shows one album. UITableView works on iOS 5.1.
@interface GLAlbumCell : UITableViewCell
@property (nonatomic, strong) CALayer *art;
@property (nonatomic, strong) UILabel *albumTitle;
@property (nonatomic, strong) UILabel *artist;
@end

@implementation GLAlbumCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = GLBackgroundColor();
        self.contentView.backgroundColor = GLBackgroundColor();
        _art = [CALayer layer];
        _art.contentsGravity = kCAGravityResizeAspectFill;
        _art.masksToBounds = YES;
        _art.cornerRadius = 3;
        _art.backgroundColor = GLSurfaceColor().CGColor;
        _art.actions = @{ @"contents": [NSNull null] };
        [self.contentView.layer addSublayer:_art];
        _albumTitle = [UILabel new];
        _albumTitle.font = GLBoldFont(15);
        _albumTitle.textColor = GLTextColor();
        _albumTitle.backgroundColor = GLBackgroundColor();
        [self.contentView addSubview:_albumTitle];
        _artist = [UILabel new];
        _artist.font = GLFont(13);
        _artist.textColor = GLSecondaryTextColor();
        _artist.backgroundColor = GLBackgroundColor();
        [self.contentView addSubview:_artist];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat height = self.contentView.bounds.size.height;
    _art.frame = CGRectMake(10, (height - 52) / 2, 52, 52);
    CGFloat x = 74;
    CGFloat width = MAX(0, self.contentView.bounds.size.width - x - 10);
    _albumTitle.frame = CGRectMake(x, (height - 38) / 2, width, 20);
    _artist.frame = CGRectMake(x, (height - 38) / 2 + 20, width, 18);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    self.art.opacity = selected ? 0.6 : 1;
}

@end

@interface GLAlbumsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray *albums;
@property (nonatomic, strong) NSArray *visibleAlbums;
@property (nonatomic) NSUInteger loadToken;
@end

@implementation GLAlbumsViewController

- (id)init {
    if ((self = [super init])) {
        self.title = @"Albums";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-albums.png"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GLBackgroundColor();
    CGRect bounds = self.view.bounds;
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search albums";
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchBar];
    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, bounds.size.width, bounds.size.height - 44)
                                              style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = GLBackgroundColor();
    self.table.separatorColor = GLSurfaceColor();
    self.table.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.table.dataSource = self;
    self.table.delegate = self;
    [self.view addSubview:self.table];
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, 120, bounds.size.width - 60, 60)];
    self.emptyLabel.font = GLFont(15);
    self.emptyLabel.textColor = GLSecondaryTextColor();
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    self.emptyLabel.textAlignment = 1;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload)
                                                 name:GLLibraryDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reload {
    NSUInteger token = ++self.loadToken;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSArray *albums = [[GLLibrary shared] albumsOfArtist:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token != self.loadToken) return;
            self.albums = albums;
            [self applySearch];
        });
    });
}

- (void)applySearch {
    NSString *text = self.searchBar.text;
    if (text.length) {
        NSPredicate *match = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@", text, text];
        self.visibleAlbums = [self.albums filteredArrayUsingPredicate:match];
    } else {
        self.visibleAlbums = self.albums;
    }
    [self.table reloadData];
    self.emptyLabel.text = text.length ? @"No results" : @"No albums yet.";
    self.emptyLabel.hidden = self.visibleAlbums.count > 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleAlbums.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseIdentifier = @"album";
    GLAlbumCell *cell = (GLAlbumCell *)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) cell = [[GLAlbumCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    GLAlbum *album = [self.visibleAlbums objectAtIndex:indexPath.row];
    cell.albumTitle.text = album.title;
    cell.artist.text = album.artist;
    [[GLImageLoader shared] showArtOfAlbum:album.key path:album.artPath points:52 inLayer:cell.art];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.searchBar resignFirstResponder];
    GLAlbum *album = [self.visibleAlbums objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:[[GLAlbumViewController alloc] initWithAlbum:album] animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applySearch];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

@end
