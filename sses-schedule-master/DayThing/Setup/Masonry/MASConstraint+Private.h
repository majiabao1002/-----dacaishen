#import "MASConstraint.h"
@protocol MASConstraintDelegate;
@interface MASConstraint ()
@property (nonatomic, assign) BOOL updateExisting;
@property (nonatomic, weak) id<MASConstraintDelegate> delegate;
- (void)setLayoutConstantWithValue:(NSValue *)value;
@end
@interface MASConstraint (Abstract)
- (MASConstraint * (^)(id, NSLayoutRelation))equalToWithRelation;
- (MASConstraint *)addConstraintWithLayoutAttribute:(NSLayoutAttribute)layoutAttribute;
@end
@protocol MASConstraintDelegate <NSObject>
- (void)constraint:(MASConstraint *)constraint shouldBeReplacedWithConstraint:(MASConstraint *)replacementConstraint;
- (MASConstraint *)constraint:(MASConstraint *)constraint addConstraintWithLayoutAttribute:(NSLayoutAttribute)layoutAttribute;
@end
