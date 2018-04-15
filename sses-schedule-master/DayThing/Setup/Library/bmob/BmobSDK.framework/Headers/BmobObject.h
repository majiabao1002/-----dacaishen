#import <Foundation/Foundation.h>
#import "BmobConfig.h"
@class BmobRelation;
@interface BmobObject : NSObject
@property(nonatomic,retain)NSString *objectId;
@property(nonatomic,retain)NSDate *updatedAt;
@property(nonatomic,retain)NSDate *createdAt;
@property(nonatomic,retain)NSString * className;
+(instancetype )objectWithClassName:(NSString*)className;
+(instancetype)objectWithoutDatatWithClassName:(NSString*)className objectId:(NSString *)objectId;
-(id)initWithClassName:(NSString*)className;
-(void)setObject:(id)obj forKey:(NSString*)aKey;
-(void)addRelation:(BmobRelation *)relation forKey:(id)key;
-(void)saveAllWithDictionary:(NSDictionary*)dic;
-(id)objectForKey:(id)aKey;
#pragma mark  array add and remove
- (void)addObjectsFromArray:(NSArray *)objects forKey:(NSString *)key;
- (void)addUniqueObjectsFromArray:(NSArray *)objects forKey:(NSString *)key;
- (void)removeObjectsInArray:(NSArray *)objects forKey:(NSString *)key;
#pragma mark increment and decrment
- (void)incrementKey:(NSString *)key;
- (void)incrementKey:(NSString *)key byAmount:(NSInteger )amount;
- (void)decrementKey:(NSString *)key;
- (void)decrementKey:(NSString *)key byAmount:(NSInteger )amount;
#pragma mark networking
-(void)saveInBackground;
-(void)saveInBackgroundWithResultBlock:(BmobBooleanResultBlock)block;
-(void)updateInBackground;
-(void)updateInBackgroundWithResultBlock:(BmobBooleanResultBlock)block;
-(void)deleteInBackground;
-(void)deleteInBackgroundWithBlock:(BmobBooleanResultBlock)block;
@end
