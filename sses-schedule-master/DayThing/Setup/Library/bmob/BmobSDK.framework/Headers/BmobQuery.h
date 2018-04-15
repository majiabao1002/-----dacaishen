#import <Foundation/Foundation.h>
#import "BmobObject.h"
#import "BmobConfig.h"
#import "BmobGeoPoint.h"
@interface BmobQuery : NSObject
@property (nonatomic) NSInteger limit;
@property (nonatomic) NSInteger skip;
@property(assign)BmobCachePolicy cachePolicy;
@property (readwrite, assign) NSTimeInterval maxCacheAge;
+(BmobQuery*)queryWithClassName:(NSString *)className;
+(BmobQuery*)queryForUser;
-(id)initWithClassName:(NSString *)className;
#pragma mark 排序
- (void)orderByAscending:(NSString *)key ;
- (void)orderByDescending:(NSString *)key ;
#pragma mark 查询条件
- (void)includeKey:(NSString *)key;
-(void)selectKeys:(NSArray*)keys;
- (void)whereKey:(NSString *)key equalTo:(id)object;
- (void)whereKey:(NSString *)key notEqualTo:(id)object;
- (void)whereKey:(NSString *)key greaterThan:(id)object;
- (void)whereKey:(NSString *)key greaterThanOrEqualTo:(id)object;
- (void)whereKey:(NSString *)key lessThan:(id)object;
- (void)whereKey:(NSString *)key lessThanOrEqualTo:(id)object;
- (void)whereKey:(NSString *)key containedIn:(NSArray *)array;
- (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array;
- (void)whereKeyExists:(NSString *)key;
- (void)whereKeyDoesNotExist:(NSString *)key;
- (void)whereKey:(NSString *)key matchesQuery:(BmobQuery *)query;
- (void)whereKey:(NSString *)key doesNotMatchQuery:(BmobQuery *)query;
- (void)whereObjectKey:(NSString *)key relatedTo:(BmobObject*)object;
#pragma mark 地理位置查询
- (void)whereKey:(NSString *)key nearGeoPoint:(BmobGeoPoint *)geopoint;
- (void)whereKey:(NSString *)key nearGeoPoint:(BmobGeoPoint *)geopoint withinMiles:(double)maxDistance;
- (void)whereKey:(NSString *)key nearGeoPoint:(BmobGeoPoint *)geopoint withinKilometers:(double)maxDistance;
- (void)whereKey:(NSString *)key nearGeoPoint:(BmobGeoPoint *)geopoint withinRadians:(double)maxDistance;
- (void)whereKey:(NSString *)key withinGeoBoxFromSouthwest:(BmobGeoPoint *)southwest toNortheast:(BmobGeoPoint *)northeast;
#pragma mark 组合查询
-(void)addTheConstraintByAndOperationWithArray:(NSArray*)array;
-(void)addTheConstraintByOrOperationWithArray:(NSArray *)array;
#pragma mark 缓存方面的函数
- (BOOL)hasCachedResult;
- (void)clearCachedResult;
+ (void)clearAllCachedResults;
#pragma mark 得到对象的函数
- (void)getObjectInBackgroundWithId:(NSString *)objectId
                              block:(BmobObjectResultBlock)block;
- (void)findObjectsInBackgroundWithBlock:(BmobObjectArrayResultBlock)block;
- (void)countObjectsInBackgroundWithBlock:(BmobIntegerResultBlock)block;
@end
