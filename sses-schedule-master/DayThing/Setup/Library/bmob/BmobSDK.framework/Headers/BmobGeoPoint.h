#import <Foundation/Foundation.h>
@interface BmobGeoPoint : NSObject
@property(nonatomic)double latitude;
@property(nonatomic)double longitude;
-(id)initWithLongitude:(double)mylongitude   WithLatitude:(double)mylatitude;
-(void)setLongitude:(double)mylongitude Latitude:(double)mylatitude ;
@end
