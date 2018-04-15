#import "UIViewController+loadView.h"
#import <objc/runtime.h>
#define SHOWGIF 0
@interface UIViewController () {
}
@end
@implementation UIViewController (loadView)
#pragma mark - public method
#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
- (void)startAnimationInWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityView removeFromSuperview];
        self.activityView.center = self.view.center;
        [self.view.window addSubview:self.activityView];
        [self.activityView startAnimating];
    });
}
- (void)endAnimationInWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityView stopAnimating];
    });
}
- (void)startAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setActivityCenter];
        [self.activityView startAnimating];
    });
}
- (void)endAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityView stopAnimating];
    });
}
- (void)startAnimation1 {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.view.userInteractionEnabled = NO;
        [self setActivityCenter];
        [self.activityView startAnimating];
    });
}
- (void)endAnimation1 {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.view.userInteractionEnabled = YES;
        [self.activityView stopAnimating];
    });
}
- (void)setActivityCenter
{
    CGPoint center = [self.view convertPoint:self.view.center fromView:self.view.window];
    self.activityView.center = center;
}
#pragma mark - getter
- (UIActivityIndicatorView *)activityView
{
    UIActivityIndicatorView *activityView = objc_getAssociatedObject(self, @selector(activityView));
    if (!activityView) {
        activityView = [[UIActivityIndicatorView alloc] init];
        activityView.hidesWhenStopped = YES;
        self.activityView = activityView;
        activityView.layer.zPosition = 1000;
        activityView.activityIndicatorViewStyle= UIActivityIndicatorViewStyleWhiteLarge;
        CGRect frame = activityView.frame;
        frame.size = CGSizeMake(80, 80);
        [activityView setFrame:frame];
        CGPoint center = [self.view convertPoint:self.view.center fromView:self.view.window];
        activityView.center = center;
        activityView.layer.cornerRadius = 6;
        activityView.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.670];
        [self.view addSubview:activityView];
    }
    return activityView;
}
#pragma mark - setter
- (void)setActivityView:(UIActivityIndicatorView *)activityView {
    objc_setAssociatedObject(self, @selector(activityView), activityView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
@implementation QueryView
-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        [self makeUI];
    }
    return self;
}
- (id)init{
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        [self makeUI];
    }
    return self;
}
-(void)makeUI
{
    self.lab = [[UILabel alloc] init];
    self.lab.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.lab];
    self.btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.btn.layer.borderWidth = 1;
    self.btn.layer.borderColor = [[UIColor blackColor] CGColor];
    [self addSubview:self.btn];
    if ([[[[NSUserDefaults standardUserDefaults]objectForKey:@"AppleLanguages"]objectAtIndex:0] rangeOfString:@"zh"].location!=NSNotFound) {
        self.lab.text = @"网络发生错误";
        [self.btn setTitle:@"点击重试" forState:UIControlStateNormal];
    }else{
        self.lab.text = @"Network error";
        [self.btn setTitle:@"Click" forState:UIControlStateNormal];
    }
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    self.lab.frame = CGRectMake(100, (self.frame.size.height - 90)/2, self.frame.size.width-200, 40);
    self.btn.frame = CGRectMake(100, CGRectGetMaxY(self.lab.frame), self.frame.size.width-200, 40);
}
@end
