//
//  AppDelegate.m
//
//
//
//
//

#import "DayThingAppDelegate.h"
#import <Security/Security.h>
#import "Common.h"


@implementation DayThingAppDelegate

@synthesize window = _window;
//@synthesize splashView = _splashView;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    //[[NSUserDefaults standardUserDefaults] synchronize];
    //[[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithObjects:[[NSUserDefaults standardUserDefaults]objectForKey:kLanguageKey], nil] forKey:@"AppleLanguages"];
    /*
    if ([[[NSUserDefaults standardUserDefaults]objectForKey:kLanguageKey] isEqualToString:[NSString stringWithFormat:@"_automatic"]]) {
        [NSLocale currentLocale];
    }
    */
    [NSLocale autoupdatingCurrentLocale];
    //switching to polish locale
    //[[NSUserDefaults standardUserDefaults] synchronize];

    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]],kUserDefaultsKeyAppCurrentVersion,nil]];
    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],kUserDefaultsKeyUpdateRemindTimes,nil]];
    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], kUserDefaultsKeyOldVersion, nil]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], kUserDefaultsKeyLaunchTimesSinceNewVersion, nil]];
    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kUserTypeSchoolSectionUpper],kUserDefaultsKeyUserTypeSchoolSection,nil]];
    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kUserTypePersonStudent],kUserDefaultsKeyUserTypePerson,nil]];
    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"Me",kUserDefaultsKeyUserName, nil]];
    [[NSUserDefaults standardUserDefaults]registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],kUserDefaultsKeyReviewRequested, nil]];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.window makeKeyAndVisible];
   
    
    if (![GET_USER_DEFAULT(kUserDefaultsKeyOldVersion) isEqualToString:[NSString stringWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]]) {
        //update detected
        SET_USER_DEFAULT([NSNumber numberWithBool:NO], kUserDefaultsKeyReviewRequested);
        SET_USER_DEFAULT([NSNumber numberWithInteger:0], kUserDefaultsKeyLaunchTimesSinceNewVersion);
    }
    
    int launchTimes = (int)[[[NSUserDefaults standardUserDefaults]objectForKey:kUserDefaultsKeyLaunchTimesSinceNewVersion]integerValue];
    [[NSUserDefaults standardUserDefaults] setInteger:launchTimes + 1 forKey:kUserDefaultsKeyLaunchTimesSinceNewVersion];

    JPUSHRegisterEntity * entity = [[JPUSHRegisterEntity alloc] init];
    entity.types = UNAuthorizationOptionAlert|UNAuthorizationOptionBadge|UNAuthorizationOptionSound;
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        // NSSet<UNNotificationCategory *> *categories for iOS10 or later
        // NSSet<UIUserNotificationCategory *> *categories for iOS8 and iOS9
    }
    [JPUSHService registerForRemoteNotificationConfig:entity delegate:self];
    [JPUSHService setupWithOption:launchOptions appKey:@"e513960f7d2291c57a91699c"
                          channel:@"appstore"
                 apsForProduction:YES
            advertisingIdentifier:nil];
    
    
    return YES;

}

-(void)startupAnimationDone:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:kUserDefaultsKeyOldVersion];
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{

    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    
    //[[NSUserDefaults standardUserDefaults] synchronize];
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:kUserDefaultsKeyOldVersion];
    
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [JPUSHService registerDeviceToken:deviceToken];
}

// iOS 10 Support
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger))completionHandler {
    NSDictionary * userInfo = notification.request.content.userInfo;
    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
    }
    completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
    }
    completionHandler();
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [JPUSHService handleRemoteNotification:userInfo];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [JPUSHService handleRemoteNotification:userInfo];
}

@end
