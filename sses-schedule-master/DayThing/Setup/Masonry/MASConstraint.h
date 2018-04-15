#import "MASUtilities.h"
@interface MASConstraint : NSObject
- (MASConstraint * (^)(MASEdgeInsets insets))insets;
- (MASConstraint * (^)(CGSize offset))sizeOffset;
- (MASConstraint * (^)(CGPoint offset))centerOffset;
- (MASConstraint * (^)(CGFloat offset))offset;
- (MASConstraint * (^)(NSValue *value))valueOffset;
- (MASConstraint * (^)(CGFloat multiplier))multipliedBy;
- (MASConstraint * (^)(CGFloat divider))dividedBy;
- (MASConstraint * (^)(MASLayoutPriority priority))priority;
- (MASConstraint * (^)())priorityLow;
- (MASConstraint * (^)())priorityMedium;
- (MASConstraint * (^)())priorityHigh;
- (MASConstraint * (^)(id attr))equalTo;
- (MASConstraint * (^)(id attr))greaterThanOrEqualTo;
- (MASConstraint * (^)(id attr))lessThanOrEqualTo;
- (MASConstraint *)with;
- (MASConstraint *)and;
- (MASConstraint *)left;
- (MASConstraint *)top;
- (MASConstraint *)right;
- (MASConstraint *)bottom;
- (MASConstraint *)leading;
- (MASConstraint *)trailing;
- (MASConstraint *)width;
- (MASConstraint *)height;
- (MASConstraint *)centerX;
- (MASConstraint *)centerY;
- (MASConstraint *)baseline;
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (__TV_OS_VERSION_MIN_REQUIRED >= 9000) || (__MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
- (MASConstraint *)firstBaseline;
- (MASConstraint *)lastBaseline;
#endif
#if TARGET_OS_IPHONE || TARGET_OS_TV
- (MASConstraint *)leftMargin;
- (MASConstraint *)rightMargin;
- (MASConstraint *)topMargin;
- (MASConstraint *)bottomMargin;
- (MASConstraint *)leadingMargin;
- (MASConstraint *)trailingMargin;
- (MASConstraint *)centerXWithinMargins;
- (MASConstraint *)centerYWithinMargins;
#endif
- (MASConstraint * (^)(id key))key;
- (void)setInsets:(MASEdgeInsets)insets;
- (void)setSizeOffset:(CGSize)sizeOffset;
- (void)setCenterOffset:(CGPoint)centerOffset;
- (void)setOffset:(CGFloat)offset;
#if TARGET_OS_MAC && !(TARGET_OS_IPHONE || TARGET_OS_TV)
@property (nonatomic, copy, readonly) MASConstraint *animator;
#endif
- (void)activate;
- (void)deactivate;
- (void)install;
- (void)uninstall;
@end
#define mas_equalTo(...)                 equalTo(MASBoxValue((__VA_ARGS__)))
#define mas_greaterThanOrEqualTo(...)    greaterThanOrEqualTo(MASBoxValue((__VA_ARGS__)))
#define mas_lessThanOrEqualTo(...)       lessThanOrEqualTo(MASBoxValue((__VA_ARGS__)))
#define mas_offset(...)                  valueOffset(MASBoxValue((__VA_ARGS__)))
#ifdef MAS_SHORTHAND_GLOBALS
#define equalTo(...)                     mas_equalTo(__VA_ARGS__)
#define greaterThanOrEqualTo(...)        mas_greaterThanOrEqualTo(__VA_ARGS__)
#define lessThanOrEqualTo(...)           mas_lessThanOrEqualTo(__VA_ARGS__)
#define offset(...)                      mas_offset(__VA_ARGS__)
#endif
@interface MASConstraint (AutoboxingSupport)
- (MASConstraint * (^)(id attr))mas_equalTo;
- (MASConstraint * (^)(id attr))mas_greaterThanOrEqualTo;
- (MASConstraint * (^)(id attr))mas_lessThanOrEqualTo;
- (MASConstraint * (^)(id offset))mas_offset;
@end
