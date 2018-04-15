#import "MASViewAttribute.h"
#import "MASConstraint.h"
#import "MASLayoutConstraint.h"
#import "MASUtilities.h"
@interface MASViewConstraint : MASConstraint <NSCopying>
@property (nonatomic, strong, readonly) MASViewAttribute *firstViewAttribute;
@property (nonatomic, strong, readonly) MASViewAttribute *secondViewAttribute;
- (id)initWithFirstViewAttribute:(MASViewAttribute *)firstViewAttribute;
+ (NSArray *)installedConstraintsForView:(MAS_VIEW *)view;
@end
