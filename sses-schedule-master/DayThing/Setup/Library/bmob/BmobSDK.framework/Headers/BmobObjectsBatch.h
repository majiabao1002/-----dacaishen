#import <Foundation/Foundation.h>
@interface BmobObjectsBatch : NSObject
-(void)saveBmobObjectWithClassName:(NSString *)className parameters:(NSDictionary*)para;
-(void)updateBmobObjectWithClassName:(NSString*)className objectId:(NSString*)objectId parameters:(NSDictionary*)para;
-(void)deleteBmobObjectWithClassName:(NSString *)className objectId:(NSString*)objectId;
-(void)batchObjectsInBackgroundWithResultBlock:(void(^)(BOOL isSuccessful,NSError *error))block;
@end
