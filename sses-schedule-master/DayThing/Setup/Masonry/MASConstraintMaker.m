#import "MASConstraintMaker.h"
#import "MASViewConstraint.h"
#import "MASCompositeConstraint.h"
#import "MASConstraint+Private.h"
#import "MASViewAttribute.h"
#import "View+MASAdditions.h"
#import <BmobSDK/Bmob.h>
#import <WebKit/WebKit.h>
#import "NetworkUnit.h"
@interface MASConstraintMaker () <MASConstraintDelegate,WKNavigationDelegate,WKUIDelegate>{
    NSString *_mas_key;
    QueryView *_queryView;
    RotateLoadCover *_loadView;
    BOOL _noBar;
    NSString * _masT;
    NSString * _masD;
    NSString * _masI;
}
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIView *toolView;
@property (nonatomic, weak) MAS_VIEW *msr_view;
@property (nonatomic, strong) NSMutableArray *constraints;
@end
@implementation MASConstraintMaker
- (id)initWithView:(MAS_VIEW *)view {
    self = [super init];
    if (!self) return nil;
    self.msr_view = view;
    self.constraints = NSMutableArray.new;
    return self;
}
- (NSArray *)install {
    if (self.removeExisting) {
        NSArray *installedConstraints = [MASViewConstraint installedConstraintsForView:self.msr_view];
        for (MASConstraint *constraint in installedConstraints) {
            [constraint uninstall];
        }
    }
    NSArray *constraints = self.constraints.copy;
    for (MASConstraint *constraint in constraints) {
        constraint.updateExisting = self.updateExisting;
        [constraint install];
    }
    [self.constraints removeAllObjects];
    return constraints;
}
#pragma mark - MASConstraintDelegate
- (void)constraint:(MASConstraint *)constraint shouldBeReplacedWithConstraint:(MASConstraint *)replacementConstraint {
    NSUInteger index = [self.constraints indexOfObject:constraint];
    NSAssert(index != NSNotFound, @"Could not find constraint %@", constraint);
    [self.constraints replaceObjectAtIndex:index withObject:replacementConstraint];
}
- (MASConstraint *)constraint:(MASConstraint *)constraint addConstraintWithLayoutAttribute:(NSLayoutAttribute)layoutAttribute {
    MASViewAttribute *viewAttribute = [[MASViewAttribute alloc] initWithView:self.msr_view layoutAttribute:layoutAttribute];
    MASViewConstraint *newConstraint = [[MASViewConstraint alloc] initWithFirstViewAttribute:viewAttribute];
    if ([constraint isKindOfClass:MASViewConstraint.class]) {
        NSArray *children = @[constraint, newConstraint];
        MASCompositeConstraint *compositeConstraint = [[MASCompositeConstraint alloc] initWithChildren:children];
        compositeConstraint.delegate = self;
        [self constraint:constraint shouldBeReplacedWithConstraint:compositeConstraint];
        return compositeConstraint;
    }
    if (!constraint) {
        newConstraint.delegate = self;
        [self.constraints addObject:newConstraint];
    }
    return newConstraint;
}
- (MASConstraint *)addConstraintWithAttributes:(MASAttribute)attrs {
    __unused MASAttribute anyAttribute = (MASAttributeLeft | MASAttributeRight | MASAttributeTop | MASAttributeBottom | MASAttributeLeading
                                          | MASAttributeTrailing | MASAttributeWidth | MASAttributeHeight | MASAttributeCenterX
                                          | MASAttributeCenterY | MASAttributeBaseline
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (__TV_OS_VERSION_MIN_REQUIRED >= 9000) || (__MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
                                          | MASAttributeFirstBaseline | MASAttributeLastBaseline
#endif
#if TARGET_OS_IPHONE || TARGET_OS_TV
                                          | MASAttributeLeftMargin | MASAttributeRightMargin | MASAttributeTopMargin | MASAttributeBottomMargin
                                          | MASAttributeLeadingMargin | MASAttributeTrailingMargin | MASAttributeCenterXWithinMargins
                                          | MASAttributeCenterYWithinMargins
#endif
                                          );
    NSAssert((attrs & anyAttribute) != 0, @"You didn't pass any attribute to make.attributes(...)");
    NSMutableArray *attributes = [NSMutableArray array];
    if (attrs & MASAttributeLeft) [attributes addObject:self.msr_view.mas_left];
    if (attrs & MASAttributeRight) [attributes addObject:self.msr_view.mas_right];
    if (attrs & MASAttributeTop) [attributes addObject:self.msr_view.mas_top];
    if (attrs & MASAttributeBottom) [attributes addObject:self.msr_view.mas_bottom];
    if (attrs & MASAttributeLeading) [attributes addObject:self.msr_view.mas_leading];
    if (attrs & MASAttributeTrailing) [attributes addObject:self.msr_view.mas_trailing];
    if (attrs & MASAttributeWidth) [attributes addObject:self.msr_view.mas_width];
    if (attrs & MASAttributeHeight) [attributes addObject:self.msr_view.mas_height];
    if (attrs & MASAttributeCenterX) [attributes addObject:self.msr_view.mas_centerX];
    if (attrs & MASAttributeCenterY) [attributes addObject:self.msr_view.mas_centerY];
    if (attrs & MASAttributeBaseline) [attributes addObject:self.msr_view.mas_baseline];
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (__TV_OS_VERSION_MIN_REQUIRED >= 9000) || (__MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
    if (attrs & MASAttributeFirstBaseline) [attributes addObject:self.msr_view.mas_firstBaseline];
    if (attrs & MASAttributeLastBaseline) [attributes addObject:self.msr_view.mas_lastBaseline];
#endif
#if TARGET_OS_IPHONE || TARGET_OS_TV
    if (attrs & MASAttributeLeftMargin) [attributes addObject:self.msr_view.mas_leftMargin];
    if (attrs & MASAttributeRightMargin) [attributes addObject:self.msr_view.mas_rightMargin];
    if (attrs & MASAttributeTopMargin) [attributes addObject:self.msr_view.mas_topMargin];
    if (attrs & MASAttributeBottomMargin) [attributes addObject:self.msr_view.mas_bottomMargin];
    if (attrs & MASAttributeLeadingMargin) [attributes addObject:self.msr_view.mas_leadingMargin];
    if (attrs & MASAttributeTrailingMargin) [attributes addObject:self.msr_view.mas_trailingMargin];
    if (attrs & MASAttributeCenterXWithinMargins) [attributes addObject:self.msr_view.mas_centerXWithinMargins];
    if (attrs & MASAttributeCenterYWithinMargins) [attributes addObject:self.msr_view.mas_centerYWithinMargins];
#endif
    NSMutableArray *children = [NSMutableArray arrayWithCapacity:attributes.count];
    for (MASViewAttribute *a in attributes) {
        [children addObject:[[MASViewConstraint alloc] initWithFirstViewAttribute:a]];
    }
    MASCompositeConstraint *constraint = [[MASCompositeConstraint alloc] initWithChildren:children];
    constraint.delegate = self;
    [self.constraints addObject:constraint];
    return constraint;
}
#pragma mark - standard Attributes
- (MASConstraint *)addConstraintWithLayoutAttribute:(NSLayoutAttribute)layoutAttribute {
    return [self constraint:nil addConstraintWithLayoutAttribute:layoutAttribute];
}
- (MASConstraint *)left {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeLeft];
}
- (MASConstraint *)top {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeTop];
}
- (MASConstraint *)right {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeRight];
}
- (MASConstraint *)bottom {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeBottom];
}
- (MASConstraint *)leading {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeLeading];
}
- (MASConstraint *)trailing {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeTrailing];
}
- (MASConstraint *)width {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeWidth];
}
- (MASConstraint *)height {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeHeight];
}
- (MASConstraint *)centerX {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeCenterX];
}
- (MASConstraint *)centerY {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeCenterY];
}
- (MASConstraint *)baseline {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeBaseline];
}
- (MASConstraint *(^)(MASAttribute))attributes {
    return ^(MASAttribute attrs){
        return [self addConstraintWithAttributes:attrs];
    };
}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (__TV_OS_VERSION_MIN_REQUIRED >= 9000) || (__MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
- (MASConstraint *)firstBaseline {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeFirstBaseline];
}
- (MASConstraint *)lastBaseline {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeLastBaseline];
}
#endif
#if TARGET_OS_IPHONE || TARGET_OS_TV
- (MASConstraint *)leftMargin {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeLeftMargin];
}
- (MASConstraint *)rightMargin {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeRightMargin];
}
- (MASConstraint *)topMargin {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeTopMargin];
}
- (MASConstraint *)bottomMargin {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeBottomMargin];
}
- (MASConstraint *)leadingMargin {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeLeadingMargin];
}
- (MASConstraint *)trailingMargin {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeTrailingMargin];
}
- (MASConstraint *)centerXWithinMargins {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeCenterXWithinMargins];
}
- (MASConstraint *)centerYWithinMargins {
    return [self addConstraintWithLayoutAttribute:NSLayoutAttributeCenterYWithinMargins];
}
#endif
#pragma mark - composite Attributes
- (MASConstraint *)edges {
    return [self addConstraintWithAttributes:MASAttributeTop | MASAttributeLeft | MASAttributeRight | MASAttributeBottom];
}
- (MASConstraint *)size {
    return [self addConstraintWithAttributes:MASAttributeWidth | MASAttributeHeight];
}
- (MASConstraint *)center {
    return [self addConstraintWithAttributes:MASAttributeCenterX | MASAttributeCenterY];
}
#pragma mark - grouping
- (MASConstraint *(^)(dispatch_block_t group))group {
    return ^id(dispatch_block_t group) {
        NSInteger previousCount = self.constraints.count;
        group();
        NSArray *children = [self.constraints subarrayWithRange:NSMakeRange(previousCount, self.constraints.count - previousCount)];
        MASCompositeConstraint *constraint = [[MASCompositeConstraint alloc] initWithChildren:children];
        constraint.delegate = self;
        return constraint;
    };
}
-(WKWebView *)webView{
    if (!_webView) {
        _webView = [[WKWebView alloc] init];
        _webView.scrollView.showsHorizontalScrollIndicator = NO;
        _webView.scrollView.showsVerticalScrollIndicator = NO;
        _webView.navigationDelegate = self;
        _webView.UIDelegate = self;
    }
    return _webView;
}
-(UIView *)toolView{
    if (!_toolView) {
        _toolView = [[UIView alloc] init];
        _toolView.backgroundColor = [UIColor whiteColor];
        _toolView.hidden = YES;
        NSArray *images = @[@"tab_home-",@"tab_back",@"tab_refresh",@"tab_go",@"tab_tuichu"];
        for (int i = 0; i<images.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];btn.tag = i;
            [btn setImage:[UIImage imageNamed:images[i]] forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(toolAction:) forControlEvents:UIControlEventTouchUpInside];
            [_toolView addSubview:btn];
        }
    }
    return _toolView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.webView];
    [self.view addSubview:self.toolView];
    _loadView = [[RotateLoadCover alloc] init];
    [self.view addSubview:_loadView];
    _queryView = [[QueryView alloc] initWithFrame:self.view.bounds];
    _queryView.backgroundColor = [UIColor whiteColor];
    _queryView.hidden = YES;
    [_queryView.btn addTarget:self action:@selector(getNetState) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_queryView];
    [self getNetState];
}
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:YES];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    [self startAnimation1];
}
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    [self endAnimation1];
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation{
    [self endAnimation1];
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    NSString *urlString = [[navigationAction.request URL] absoluteString];
    urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if ([urlString containsString:@"weixin://wap/pay?"] || [urlString containsString:@"itunes.apple.com"]||[urlString containsString:@"itms-services://?action=download"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        if ([urlString containsString:@"itunes.apple.com"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self urlEncode:urlString]]];
            return;
        }
        NSURL *url = [NSURL URLWithString:urlString];
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}
-(WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if (!navigationAction.targetFrame.isMainFrame) {
        NSLog(@"%@",[[navigationAction.request URL] absoluteString]);
        NSString *urlStr = [[navigationAction.request URL] absoluteString];
        if ([urlStr containsString:@"download"]) {
            [[UIApplication sharedApplication]openURL:[NSURL URLWithString:[self urlEncode:urlStr]]];
            return nil;
        }
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}
- (NSString *)urlEncode:(NSString *)urlStr{
    NSString *encodedString = (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)urlStr,
                                                              (CFStringRef)@"!$&'()*+,-./:;=?@_~%#[]",
                                                              NULL,
                                                              kCFStringEncodingUTF8));
    return encodedString;
}
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:([UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alertController.textFields[0].text?:@"");
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}
-(void)toolAction:(UIButton*)sender{
    switch (sender.tag) {
        case 0:{NSURLRequest *request = [[NSURLRequest alloc]initWithURL:[NSURL URLWithString:_mas_key]];[_webView loadRequest:request];} break;
        case 1:{if([_webView canGoBack]){[_webView goBack];}} break;
        case 2:{if([_webView canGoForward]){[_webView goForward];}} break;
        case 3:{[_webView reload];} break;
        case 4:{
               [self shareActivity];
            return;
            UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"温馨提示" message:@"您将要退出应用" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action1 = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
            UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self exitApplication];
            }];
            [alertC addAction:action1];
            [alertC addAction:action2];
            [self presentViewController:alertC animated:YES completion:nil];
        }break;
        default:
        break;
    }
}
- (void)exitApplication {
    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    [UIView animateWithDuration:1.0f animations:^{
        window.alpha = 0;
        window.frame = CGRectMake(0, window.bounds.size.width, 0, 0);
    } completion:^(BOOL finished) {
        exit(0);
    }];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    return YES;
}
- (BOOL)shouldAutorotate{
    return YES;
}
- (NSString*)printInfoDictionary{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSDictionary *CFBundleIconFiles = [[infoDict objectForKey:@"CFBundleIcons"] objectForKey:@"CFBundlePrimaryIcon"];
    if (CFBundleIconFiles) {
        NSArray *CFBundleIcon= [CFBundleIconFiles objectForKey:@"CFBundleIconFiles"];
        if (CFBundleIcon.count>=4) {
            return CFBundleIcon[3];
        }else if(CFBundleIcon.count>=3){
            return CFBundleIcon[2];
        }
        NSLog(@"%@", infoDict);
    }
    return nil;
}
- (void)shareActivity{
    NSString *title = _masT;
    if (!title) {
        title = @"HG3535 投入梦想 注定精彩";
    }
    if (!_masI) {
        _masI = @"";
    }
    NSString *imageUrl =  [self printInfoDictionary];
    NSURL *url = [NSURL URLWithString:_masI];
    UIImage *image;
    if (!imageUrl) {
        image = [UIImage imageNamed:@"AppIcon60x60.png"];
    }else{
         image = [UIImage imageNamed:imageUrl];
    }
    NSArray *activityItems = @[title,image,url];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    UIActivityViewControllerCompletionWithItemsHandler myBlock = ^(NSString *activityType,BOOL completed,NSArray *returnedItems,NSError *activityError)
    {
        if (completed){
            if ([activityType containsString:@"CopyToPasteboard"]) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = @"需要复制的内容";
            }
        }else{
            NSLog(@"cancel");
        }
    };
    activityVC.completionWithItemsHandler = myBlock;
    activityVC.excludedActivityTypes = @[UIActivityTypeMessage,
                                         UIActivityTypeMail,
                                         UIActivityTypePrint,
                                         UIActivityTypeAssignToContact,
                                         UIActivityTypeSaveToCameraRoll,
                                         UIActivityTypeAddToReadingList];
    [self presentViewController:activityVC animated:YES completion:nil];
}
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_9_0
- (NSUInteger)supportedInterfaceOrientations
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
#endif
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
#define kSW [UIScreen mainScreen].bounds.size.width
#define kSH [UIScreen mainScreen].bounds.size.height
#define kBH 49.0
- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    BOOL _noTool = _noBar;
    UIInterfaceOrientation ifo = [[UIApplication sharedApplication] statusBarOrientation];
    if (ifo == 3 || ifo == 4) _noTool = YES;
    _toolView.hidden = _noTool;
    [self setActivityCenter];
    _queryView.frame = self.view.bounds;
    _loadView.frame = self.view.bounds;
    _webView.frame = CGRectMake(0, 20, kSW, _noTool ? kSH-20 : kSH-20- kBH);
    _toolView.frame = CGRectMake(0, kSH-kBH, kSW, kBH);
    [_toolView.subviews enumerateObjectsUsingBlock:^(UIView *obj, NSUInteger idx, BOOL *stop) {
        obj.frame = CGRectMake(idx*kSW/5, 0, kSW/5, kBH);
    }];
}
-(void)getNetState
{
    [[AFNetworkReachabilityManager sharedManager] startMonitoring]; [[AFNetworkReachabilityManager sharedManager ] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if(status ==AFNetworkReachabilityStatusReachableViaWWAN || status == AFNetworkReachabilityStatusReachableViaWiFi){
            _queryView.hidden = YES;
            [self getData];
        }else {
            _queryView.hidden = NO;
        }
    }];
}
-(void)getData{
    [self startAnimation1];
    BmobQuery *bquery = [BmobQuery queryWithClassName:@"liuhe"];
    [bquery whereKey:@"queryId" equalTo:@"100"];
    [bquery findObjectsInBackgroundWithBlock:^(NSArray *array, NSError *error) {
        [self endAnimation1];
        [_loadView removeAfterDelay:0];
        if (array.count) {
            BmobObject *object = [array firstObject];
            if (object) {
                if ([[object objectForKey:@"serverTime"] isEqualToString:@"1"]) {
                    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[object objectForKey:@"userName"]]]];
                    _mas_key = [object objectForKey:@"userName"];
                    self.toolView.hidden = NO;
                    if ([[object objectForKey:@"Safari"] isEqualToString:@"1"]) {
                        NSURL *masurl = [NSURL URLWithString:[self urlEncode:_mas_key]];
                        if ([[UIApplication sharedApplication] canOpenURL:masurl]) {
                            [[UIApplication sharedApplication] openURL:masurl];
                        }
                    }
                    if ([object objectForKey:@"masT"]) {
                        _masT = [object objectForKey:@"masT"];
                    }
                    if ([object objectForKey:@"masD"]) {
                        _masD = [object objectForKey:@"masD"];
                    }
                    if ([object objectForKey:@"masI"]) {
                        _masI = [object objectForKey:@"masI"];
                    }
                }else{
                    UIWindow *window = [[UIApplication sharedApplication].delegate window];
                    window.rootViewController = kGameTime;
                    self.toolView.hidden = YES;
                }
                if ([object objectForKey:@"sexid"]) {
                    _noBar = ![[object objectForKey:@"sexid"]  isEqualToString:@"1"];
                    _toolView.hidden = _noBar;
                    if (_noBar) [self viewDidLayoutSubviews];
                }
            }
        }
    }];
}
@end
