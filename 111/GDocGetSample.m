// 「レシピ111 :GoogleDocsのテキストファイルを変更する」のサンプルコード (P.302)

#import "GDataDocs.h"
@interface GDocGetSample : UITableViewController {
    GDataServiceGoogleDocs *service;
    GDataFeedDocList *docList;
}
@end

@implementation GDocGetSample

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [[docList entries] count];
}
- (NSString*)getDocKind:(GDataEntryDocBase *)doc
{
    // ドキュメントの種類を取得する
    NSString *docKind = @"unknown";
    NSLog(@"%@",[[doc alternateLink] URL ]);
    NSArray *categories;
    categories = [GDataCategory categoriesWithScheme:kGDataCategoryScheme
                                      fromCategories:[doc categories]];
    if ([categories count] >= 1) {
        docKind = [[categories objectAtIndex:0] label];
    }
    return docKind;
}
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *kCellID = @"cellID";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID];
    if (cell == nil)
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellID] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.row < [[docList entries] count]) {
        GDataEntryDocBase *doc = [docList entryAtIndex:indexPath.row];
        NSString *docKind = [self getDocKind:doc];
        // スター付き
        if ([doc isStarred]) {
            docKind = [NSString stringWithFormat:@"★ %@",docKind];
        }

        NSString *displayStr = [NSString stringWithFormat:@"%@ (%@)",
                                [[doc title] stringValue], docKind];
        cell.textLabel.text = displayStr;
    }
    return cell;
}

// docList list fetch callback
- (void)docListFetchTicket:(GDataServiceTicket *)ticket
          finishedWithFeed:(GDataFeedDocList *)feed
                     error:(NSError *)error {
    if (error) {
        NSLog(@"fetch error: %@", error);
        return;
    }
    [docList release];
    docList = feed;
    [docList retain];
    [self.tableView reloadData];
}

- (void) getList {
    // fetchDocsFeedWithURLはリストの25%しかとれない。
    //（さらに取得するときはfeedのnextリンクを使う)
    // 一度に取りたいときは、GDataQueryDocsオブジェクトを作成して
    // fetchFeedWithQueryを使う
    NSURL *feedURL = [GDataServiceGoogleDocs docsFeedURLUsingHTTPS:YES];

    GDataQueryDocs *query =
        [GDataQueryDocs documentQueryWithFeedURL:feedURL];
    [query setMaxResults:1000];
    [query setShouldShowFolders:YES];

    GDataServiceTicket *ticket;

    ticket =
        [service fetchFeedWithQuery:query
        delegate:self
        didFinishSelector:
        @selector(docListFetchTicket:finishedWithFeed:error:)];
}
-(void)setupService:(NSString*)username password:(NSString*)password {
    service = [[[GDataServiceGoogleDocs alloc] init] autorelease];
    [service setUserCredentialsWithUsername:username
                                   password:password];
    [service retain];

    // エージェントを設定(書式:yourName-appName-appVersion)
    [service setUserAgent:@"MyCompany-GSample-1.0"];

    // パフォーマンスを良くするため
    [service setServiceShouldFollowNextLinks:YES];
    //[query setMaxResults:1000];
    [service setShouldCacheDatedData:YES];
    // YESにすると、取得したXMLをパースしないので高速化できるが、データの変更は
    // 出来なくなる
    [service setShouldServiceFeedsIgnoreUnknowns:NO];
}

-(id)initWithStyle:(UITableViewStyle)style {
    if ([super initWithStyle:style]!=nil) {
        self.title = @"Google Documents";
        self.tableView.scrollEnabled = YES;

        docList = [[GDataFeedDocList alloc]init];
    }
    return self;
}
- (void)dealloc
{
    [docList release];
    [service release];

    [super dealloc];
}
- (void)fetcher:(GDataHTTPFetcher *)fetcher finishedWithData:(NSData *)data
{
    // データのダウンロードが完了したらファイルに保存する
    GDataEntryDocBase *doc = [fetcher userData];
    NSString *savePath = [NSString stringWithFormat:@"%@/Documents/%@.%@",
                          NSHomeDirectory(),[[doc title] stringValue],@"txt"];
    NSError *error = nil;

    BOOL didWrite = [data writeToFile:savePath options:NSAtomicWrite
                                error:&error];
    if (!didWrite) {
        NSLog(@"Error saving file: %@", error);
    } else {
        NSLog(@"Success save file: %@", savePath);

        //ここからファイルアップロード用

        //内容編集用のビューコントローラを表示
        GDocEdit *detailViewC =
        [[GDocEdit alloc] initWithService:service path:savePath doc:doc];
        [self.navigationController pushViewController:detailViewC
                                             animated:YES];
        //ここまでファイルアップロード用
    }
}
- (void)fetcher:(GDataHTTPFetcher *)fetcher failedWithError:(NSError *)error
{
    NSString *savePath = [fetcher userData];
    NSLog(@"Fetcher error: %@ : %@", error,savePath);
}
- (void)downloadFile:(GDataEntryDocBase *)doc extention:(NSString*)ext
{
    // ダウンロードするURLを生成し、ダウンロードを開始
    if (!service) {
        return;
    }
    GDataQuery *query =
    [GDataQuery queryWithFeedURL:[[doc content] sourceURL]];
    [query addCustomParameterWithName:@"exportFormat"
                                value:ext];
    NSURL *downloadURL = [query URL];
    NSLog(@"loading %@",downloadURL);
    NSURLRequest *request = [service requestForURL:downloadURL
                                              ETag:nil
                                        httpMethod:nil];
    GDataHTTPFetcher *fetcher =
    [GDataHTTPFetcher httpFetcherWithRequest:request];
    [fetcher setUserData:doc];
    [fetcher beginFetchWithDelegate:self
                  didFinishSelector:@selector(fetcher:finishedWithData:)
                    didFailSelector:@selector(fetcher:failedWithError:)];
}
- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [[docList entries] count]) {
        return;
    }
    GDataEntryDocBase *doc = [docList entryAtIndex:indexPath.row];
    NSString *docKind = [self getDocKind:doc];
    if ([docKind isEqualToString:@"document"]) {
        if ([[doc content] sourceURL]) {
            NSString *ext = @"txt";
            [self downloadFile:doc extention:ext];
        }
    }
}

@end

@interface GDocEdit : UIViewController
{
    GDataServiceGoogleDocs *service;
    GDataEntryDocBase *doc;
    NSString *dataPath;
    UITextField *titleField;
    UITextView *textView;
}
@end

@implementation GDocEdit
- (void)uploadTicket:(GDataServiceTicket *)ticket
       finishedWithEntry:(GDataEntryDocBase *)entry
                   error:(NSError *)error {
      if (error == nil) {
          NSLog(@"File upload success");
      }else{
          NSLog(@"File upload failed: %@", error);
      }
}

-(void) uploadFile
{
    NSData *data = [textView.text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return;
    }
    NSString *fileName = [dataPath lastPathComponent];
    [doc setUploadSlug:fileName];
    [doc setUploadData:data];
    [doc setUploadMIMEType:@"text/plain"];

    NSString *title = titleField.text;
    [doc setTitleWithString:title];

    GDataServiceTicket *updateTicket;
    updateTicket = [service fetchEntryByUpdatingEntry:doc delegate:self
        didFinishSelector:@selector(uploadTicket:finishedWithEntry:error:)];

}

-(id) initWithService:(GDataServiceGoogleDocs *)parentService
                 path:(NSString*)path
                  doc:(GDataEntryDocBase *)targetDoc
{
    [super initWithNibName:nil bundle:nil];
    service = parentService;
    doc = targetDoc;
    dataPath = path;
    [service retain];
    [doc retain];
    [dataPath retain];

    titleField = [[[UITextField alloc]initWithFrame:CGRectMake(0,0,320,50)]
                  retain];
    titleField.text = [[doc title] stringValue];
    [self.view addSubview:titleField];
    textView = [[[UITextView alloc]initWithFrame:CGRectMake(0,50,320,410)]
                retain];
    textView.text = [NSString stringWithContentsOfFile:dataPath
        encoding:NSUTF8StringEncoding error:nil];
    [self.view addSubview:textView];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]initWithTitle:@"Upload"
        style:UIBarButtonItemStyleBordered
        target:self
        action:@selector(uploadFile)];
    return self;
}

-(void)dealloc {
    [service release];
    [doc release];
    [dataPath release];
    [titleField release];
    [textView release];
    [super dealloc];
}
@end