#import <Foundation/Foundation.h>
#import "BmobConfig.h"
#import "BmobObject.h"
@interface BmobUser : BmobObject
@property(nonatomic,retain)NSString *objectId;
@property(nonatomic,retain)NSDate *updatedAt;
@property(nonatomic,retain)NSDate *createdAt;
#pragma mark set
-(void)setUserName:(NSString*)username;
-(void)setPassword:(NSString*)password;
-(void)setEmail:(NSString *)email;
-(void)setObject:(id)obj forKey:(id)key;
-(void)saveAllWithDictionary:(NSDictionary *)dic;
+(void)logInWithUsernameInBackground:(NSString*)username
                            password:(NSString*)password;
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(BmobUserResultBlock)block;
+(void)logout;
-(void)signUpInBackground;
-(void)signUpInBackgroundWithBlock:(BmobBooleanResultBlock)block;
-(void)verifyEmailInBackgroundWithEmailAddress:(NSString *)email;
+(void)requestPasswordResetInBackgroundWithEmail:(NSString *)email;
+(BmobUser*)getCurrentObject;
+(BmobUser*)getCurrentUser;
@end
