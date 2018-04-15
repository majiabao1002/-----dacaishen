#import "NSArray+MASAdditions.h"
#ifdef MAS_SHORTHAND
@interface NSArray (MASShorthandAdditions)
- (NSArray *)makeConstraints:(void(^)(MASConstraintMaker *make))block;
- (NSArray *)updateConstraints:(void(^)(MASConstraintMaker *make))block;
- (NSArray *)remakeConstraints:(void(^)(MASConstraintMaker *make))block;
@end
@implementation NSArray (MASShorthandAdditions)
- (NSArray *)makeConstraints:(void(^)(MASConstraintMaker *))block {
    return [self mas_makeConstraints:block];
}
- (NSArray *)updateConstraints:(void(^)(MASConstraintMaker *))block {
    return [self mas_updateConstraints:block];
}
- (NSArray *)remakeConstraints:(void(^)(MASConstraintMaker *))block {
    return [self mas_remakeConstraints:block];
}
@end
#endif
