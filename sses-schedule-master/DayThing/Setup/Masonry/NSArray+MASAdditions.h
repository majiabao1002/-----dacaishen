#import "MASUtilities.h"
#import "MASConstraintMaker.h"
#import "MASViewAttribute.h"
typedef NS_ENUM(NSUInteger, MASAxisType) {
    MASAxisTypeHorizontal,
    MASAxisTypeVertical
};
@interface NSArray (MASAdditions)
- (NSArray *)mas_makeConstraints:(void (^)(MASConstraintMaker *make))block;
- (NSArray *)mas_updateConstraints:(void (^)(MASConstraintMaker *make))block;
- (NSArray *)mas_remakeConstraints:(void (^)(MASConstraintMaker *make))block;
- (void)mas_distributeViewsAlongAxis:(MASAxisType)axisType withFixedSpacing:(CGFloat)fixedSpacing leadSpacing:(CGFloat)leadSpacing tailSpacing:(CGFloat)tailSpacing;
- (void)mas_distributeViewsAlongAxis:(MASAxisType)axisType withFixedItemLength:(CGFloat)fixedItemLength leadSpacing:(CGFloat)leadSpacing tailSpacing:(CGFloat)tailSpacing;
@end
