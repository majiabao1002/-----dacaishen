#import <Foundation/Foundation.h>
#import "BmobObject.h"
@interface BmobRelation : NSObject
-(void)addObject:(BmobObject *)object;
-(void)removeObject:(BmobObject *)object;
@end
