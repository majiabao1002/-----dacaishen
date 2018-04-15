#define JPUSH_VERSION_NUMBER 3.0.6
#import <Foundation/Foundation.h>
@class CLRegion;
@class UILocalNotification;
@class CLLocation;
@class UNNotificationCategory;
@class UNNotificationSettings;
@class UNNotificationRequest;
@class UNNotification;
@protocol JPUSHRegisterDelegate;
typedef void (^JPUSHTagsOperationCompletion)(NSInteger iResCode, NSSet *iTags, NSInteger seq);
typedef void (^JPUSHTagValidOperationCompletion)(NSInteger iResCode, NSSet *iTags, NSInteger seq, BOOL isBind);
typedef void (^JPUSHAliasOperationCompletion)(NSInteger iResCode, NSString *iAlias, NSInteger seq);
extern NSString *const kJPFNetworkIsConnectingNotification; 
extern NSString *const kJPFNetworkDidSetupNotification;     
extern NSString *const kJPFNetworkDidCloseNotification;     
extern NSString *const kJPFNetworkDidRegisterNotification;  
extern NSString *const kJPFNetworkFailedRegisterNotification; 
extern NSString *const kJPFNetworkDidLoginNotification;     
extern NSString *const kJPFNetworkDidReceiveMessageNotification;         
extern NSString *const kJPFServiceErrorNotification;  
typedef NS_OPTIONS(NSUInteger, JPAuthorizationOptions) {
    JPAuthorizationOptionNone    = 0,   
    JPAuthorizationOptionBadge   = (1 << 0),    
    JPAuthorizationOptionSound   = (1 << 1),    
    JPAuthorizationOptionAlert   = (1 << 2),    
};
@interface JPUSHRegisterEntity : NSObject
@property (nonatomic, assign) NSInteger types;
@property (nonatomic, strong) NSSet *categories;
@end
@interface JPushNotificationIdentifier : NSObject<NSCopying, NSCoding>
@property (nonatomic, copy) NSArray<NSString *> *identifiers; 
@property (nonatomic, copy) UILocalNotification *notificationObj NS_DEPRECATED_IOS(4_0, 10_0);  
@property (nonatomic, assign) BOOL delivered NS_AVAILABLE_IOS(10_0); 
@property (nonatomic, copy) void (^findCompletionHandler)(NSArray *results); 
@end
@interface JPushNotificationContent : NSObject<NSCopying, NSCoding>
@property (nonatomic, copy) NSString *title;                
@property (nonatomic, copy) NSString *subtitle;             
@property (nonatomic, copy) NSString *body;                 
@property (nonatomic, copy) NSNumber *badge;                
@property (nonatomic, copy) NSString *action NS_DEPRECATED_IOS(8_0, 10_0); 
@property (nonatomic, copy) NSString *categoryIdentifier;   
@property (nonatomic, copy) NSDictionary *userInfo;         
@property (nonatomic, copy) NSString *sound;                
@property (nonatomic, copy) NSArray *attachments NS_AVAILABLE_IOS(10_0);                 
@property (nonatomic, copy) NSString *threadIdentifier NS_AVAILABLE_IOS(10_0); 
@property (nonatomic, copy) NSString *launchImageName NS_AVAILABLE_IOS(10_0);  
@end
@interface JPushNotificationTrigger : NSObject<NSCopying, NSCoding>
@property (nonatomic, assign) BOOL repeat;                  
@property (nonatomic, copy) NSDate *fireDate NS_DEPRECATED_IOS(2_0, 10_0);           
@property (nonatomic, copy) CLRegion *region NS_AVAILABLE_IOS(8_0);                  
@property (nonatomic, copy) NSDateComponents *dateComponents NS_AVAILABLE_IOS(10_0); 
@property (nonatomic, assign) NSTimeInterval timeInterval NS_AVAILABLE_IOS(10_0);    
@end
@interface JPushNotificationRequest : NSObject<NSCopying, NSCoding>
@property (nonatomic, copy) NSString *requestIdentifier;    
@property (nonatomic, copy) JPushNotificationContent *content; 
@property (nonatomic, copy) JPushNotificationTrigger *trigger; 
@property (nonatomic, copy) void (^completionHandler)(id result); 
@end
@interface JPUSHService : NSObject
+ (void)setupWithOption:(NSDictionary *)launchingOption __attribute__((deprecated("JPush 2.1.0 版本已过期")));
+ (void)setupWithOption:(NSDictionary *)launchingOption
                 appKey:(NSString *)appKey
                channel:(NSString *)channel
       apsForProduction:(BOOL)isProduction;
+ (void)setupWithOption:(NSDictionary *)launchingOption
                 appKey:(NSString *)appKey
                channel:(NSString *)channel
       apsForProduction:(BOOL)isProduction
  advertisingIdentifier:(NSString *)advertisingId;
+ (void)registerForRemoteNotificationTypes:(NSUInteger)types
                                categories:(NSSet *)categories;
+ (void)registerForRemoteNotificationConfig:(JPUSHRegisterEntity *)config delegate:(id<JPUSHRegisterDelegate>)delegate;
+ (void)registerDeviceToken:(NSData *)deviceToken;
+ (void)handleRemoteNotification:(NSDictionary *)remoteInfo;
+ (void)addTags:(NSSet<NSString *> *)tags
     completion:(JPUSHTagsOperationCompletion)completion
            seq:(NSInteger)seq;
+ (void)setTags:(NSSet<NSString *> *)tags
     completion:(JPUSHTagsOperationCompletion)completion
            seq:(NSInteger)seq;
+ (void)deleteTags:(NSSet<NSString *> *)tags
        completion:(JPUSHTagsOperationCompletion)completion
               seq:(NSInteger)seq;
+ (void)cleanTags:(JPUSHTagsOperationCompletion)completion
              seq:(NSInteger)seq;
+ (void)getAllTags:(JPUSHTagsOperationCompletion)completion
               seq:(NSInteger)seq;
+ (void)validTag:(NSString *)tag
      completion:(JPUSHTagValidOperationCompletion)completion
             seq:(NSInteger)seq;
+ (void)setAlias:(NSString *)alias
      completion:(JPUSHAliasOperationCompletion)completion
             seq:(NSInteger)seq;
+ (void)deleteAlias:(JPUSHAliasOperationCompletion)completion
                seq:(NSInteger)seq;
+ (void)getAlias:(JPUSHAliasOperationCompletion)completion
             seq:(NSInteger)seq;
+ (NSSet *)filterValidTags:(NSSet *)tags;
+ (void)startLogPageView:(NSString *)pageName;
+ (void)stopLogPageView:(NSString *)pageName;
+ (void)beginLogPageView:(NSString *)pageName duration:(int)seconds;
+ (void)crashLogON;
+ (void)setLatitude:(double)latitude longitude:(double)longitude;
+ (void)setLocation:(CLLocation *)location;
+ (void)addNotification:(JPushNotificationRequest *)request;
+ (void)removeNotification:(JPushNotificationIdentifier *)identifier;
+ (void)findNotification:(JPushNotificationIdentifier *)identifier;
+ (UILocalNotification *)setLocalNotification:(NSDate *)fireDate
                                    alertBody:(NSString *)alertBody
                                        badge:(int)badge
                                  alertAction:(NSString *)alertAction
                                identifierKey:(NSString *)notificationKey
                                     userInfo:(NSDictionary *)userInfo
                                    soundName:(NSString *)soundName __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (UILocalNotification *)setLocalNotification:(NSDate *)fireDate
                                    alertBody:(NSString *)alertBody
                                        badge:(int)badge
                                  alertAction:(NSString *)alertAction
                                identifierKey:(NSString *)notificationKey
                                     userInfo:(NSDictionary *)userInfo
                                    soundName:(NSString *)soundName
                                       region:(CLRegion *)region
                           regionTriggersOnce:(BOOL)regionTriggersOnce
                                     category:(NSString *)category NS_AVAILABLE_IOS(8_0) __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (void)showLocalNotificationAtFront:(UILocalNotification *)notification
                       identifierKey:(NSString *)notificationKey __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (void)deleteLocalNotificationWithIdentifierKey:(NSString *)notificationKey __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (void)deleteLocalNotification:(UILocalNotification *)localNotification __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (NSArray *)findLocalNotificationWithIdentifier:(NSString *)notificationKey __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (void)clearAllLocalNotifications __attribute__((deprecated("JPush 2.1.9 版本已过期")));
+ (BOOL)setBadge:(NSInteger)value;
+ (void)resetBadge;
+ (NSString *)registrationID;
+ (void)registrationIDCompletionHandler:(void(^)(int resCode,NSString *registrationID))completionHandler;
+ (void)setDebugMode;
+ (void)setLogOFF;
+ (void) setTags:(NSSet *)tags
           alias:(NSString *)alias
callbackSelector:(SEL)cbSelector
          target:(id)theTarget __attribute__((deprecated("JPush 2.1.1 版本已过期")));
+ (void) setTags:(NSSet *)tags
           alias:(NSString *)alias
callbackSelector:(SEL)cbSelector
          object:(id)theTarget __attribute__((deprecated("JPush 3.0.6 版本已过期")));
+ (void) setTags:(NSSet *)tags
callbackSelector:(SEL)cbSelector
          object:(id)theTarget __attribute__((deprecated("JPush 3.0.6 版本已过期")));
+ (void)setTags:(NSSet *)tags
          alias:(NSString *)alias
fetchCompletionHandle:(void (^)(int iResCode, NSSet *iTags, NSString *iAlias))completionHandler __attribute__((deprecated("JPush 3.0.6 版本已过期")));
+ (void)  setTags:(NSSet *)tags
aliasInbackground:(NSString *)alias __attribute__((deprecated("JPush 3.0.6 版本已过期")));
+ (void)setAlias:(NSString *)alias
callbackSelector:(SEL)cbSelector
          object:(id)theTarget __attribute__((deprecated("JPush 3.0.6 版本已过期")));
@end
@class UNUserNotificationCenter;
@class UNNotificationResponse;
@protocol JPUSHRegisterDelegate <NSObject>
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger options))completionHandler;
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler;
@end
