#import <UIKit/UIKit.h>
@interface QueryView : UIView
@property (nonatomic ,strong) UIButton *btn;
@property (nonatomic ,strong) UILabel *lab;
@end
@interface UIViewController (loadView)
@property UIActivityIndicatorView *activityView;
- (void)startAnimation;
- (void)endAnimation;
- (void)startAnimation1;
- (void)endAnimation1;
- (void)startAnimationInWindow;
- (void)endAnimationInWindow;
- (void)setActivityCenter;
@end
