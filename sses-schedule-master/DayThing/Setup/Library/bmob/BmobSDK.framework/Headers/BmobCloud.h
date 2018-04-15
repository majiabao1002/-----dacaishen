#import <Foundation/Foundation.h>
#import "BmobConfig.h"
@interface BmobCloud : NSObject
+ (id)callFunction:(NSString *)function withParameters:(NSDictionary *)parameters;
+ (void)callFunctionInBackground:(NSString *)function withParameters:(NSDictionary *)parameters block:(BmobIdResultBlock)block;
@end
