//
//  AppDelegate.h
//
//
//
//
//

#import <UIKit/UIKit.h>
extern NSString *const SessionStateChangedNotification;

@interface DayThingAppDelegate : UIResponder <UIApplicationDelegate,UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;

//@property (strong, nonatomic) UIImageView *splashView;

- (void)startupAnimationDone:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

@end
