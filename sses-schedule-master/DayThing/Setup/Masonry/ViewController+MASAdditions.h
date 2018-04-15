#import "MASUtilities.h"
#import "MASConstraintMaker.h"
#import "MASViewAttribute.h"
#ifdef MAS_VIEW_CONTROLLER
@interface MAS_VIEW_CONTROLLER (MASAdditions)
@property (nonatomic, strong, readonly) MASViewAttribute *mas_topLayoutGuide;
@property (nonatomic, strong, readonly) MASViewAttribute *mas_bottomLayoutGuide;
@property (nonatomic, strong, readonly) MASViewAttribute *mas_topLayoutGuideTop;
@property (nonatomic, strong, readonly) MASViewAttribute *mas_topLayoutGuideBottom;
@property (nonatomic, strong, readonly) MASViewAttribute *mas_bottomLayoutGuideTop;
@property (nonatomic, strong, readonly) MASViewAttribute *mas_bottomLayoutGuideBottom;
@end
#endif
