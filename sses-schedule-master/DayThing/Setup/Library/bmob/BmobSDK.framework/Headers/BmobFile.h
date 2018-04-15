#import <Foundation/Foundation.h>
#import "BmobConfig.h"
@interface BmobFile : NSObject
@property(nonatomic,retain)NSString  *name;
@property(nonatomic,retain)NSString  *url;
@property(nonatomic,retain)NSString  *group;
-(id)initWithClassName:(NSString*)className withFilePath:(NSString*)filePath;
-(id)initWithClassName:(NSString *)className  withFileName:(NSString*)fileName  withFileData:(NSData*)data;
-(BOOL)save;
-(void)saveInBackground:(BmobBooleanResultBlock)block;
-(void)saveInBackground:(BmobBooleanResultBlock)block withProgressBlock:(void(^)(float progress))progressBlock;
-(void)cancle;
@end
