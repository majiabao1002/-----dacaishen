#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "BmobObject.h"
#import "BmobFile.h"
#import "BmobGeoPoint.h"
#import "BmobQuery.h"
#import "BmobUser.h"
#import "BmobCloud.h"
#import "BmobConfig.h"
#import "BmobRelation.h"
#import "BmobObjectsBatch.h"
#import "BmobPush.h"
#import "BmobInstallation.h"
@interface Bmob : NSObject
+(void)registerWithAppKey:(NSString*)appKey;
+(NSString*)getServerTimestamp;
@end
