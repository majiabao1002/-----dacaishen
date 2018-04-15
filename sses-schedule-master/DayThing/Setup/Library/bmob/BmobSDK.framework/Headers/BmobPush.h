#import <Foundation/Foundation.h>
#import "BmobConfig.h"
@class BmobQuery;
@interface BmobPush : NSObject
+ (BmobPush*)push;
- (void)setQuery:(BmobQuery*)query;
- (void)setChannels:(NSArray *)channels;
- (void)setChannel:(NSString *)channel;
- (void)setMessage:(NSString *)message;
- (void)setData:(NSDictionary *)data;
- (void)expireAtDate:(NSDate *)date;
- (void)expireAfterTimeInterval:(NSTimeInterval)timeInterval;
- (void)pushDate:(NSDate *)date;
- (void)sendPushInBackground;
- (void)sendPushInBackgroundWithBlock:(BmobBooleanResultBlock)block;
+ (void)sendPushMessageToChannelInBackground:(NSString *)channel
                                 withMessage:(NSString *)message;
+ (void)sendPushMessageToChannelInBackground:(NSString *)channel
                                 withMessage:(NSString *)message
                                       block:(BmobBooleanResultBlock)block;
+ (void)sendPushMessageToQueryInBackground:(BmobQuery *)query
                               withMessage:(NSString *)message;
+ (void)sendPushMessageToQueryInBackground:(BmobQuery *)query
                               withMessage:(NSString *)message
                                     block:(BmobBooleanResultBlock)block;
+ (void)sendPushDataToChannelInBackground:(NSString *)channel
                                 withData:(NSDictionary *)data;
+ (void)sendPushDataToChannelInBackground:(NSString *)channel
                                 withData:(NSDictionary *)data
                                    block:(BmobBooleanResultBlock)block;
+ (void)sendPushDataToQueryInBackground:(BmobQuery *)query
                               withData:(NSDictionary *)data;
+ (void)sendPushDataToQueryInBackground:(BmobQuery *)query
                               withData:(NSDictionary *)data
                                  block:(BmobBooleanResultBlock)block;
+ (void)handlePush:(NSDictionary *)userInfo;
@end
