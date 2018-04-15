#import <Foundation/Foundation.h>
#import "BmobObject.h"
@class BmobQuery;
@interface BmobInstallation : BmobObject
+(BmobQuery *)query;
+(instancetype)currentInstallation;
- (void)setDeviceTokenFromData:(NSData *)deviceTokenData;
@property (nonatomic,readonly,retain) NSString *deviceType;
@property (nonatomic,retain) NSString          *deviceToken;
@property (nonatomic,assign) int               badge;
@property (nonatomic, retain) NSArray          *channels;
-(void)subsccribeToChannels:(NSArray*)channels;
-(void)unsubscribeFromChannels:(NSArray*)channels;
@end
