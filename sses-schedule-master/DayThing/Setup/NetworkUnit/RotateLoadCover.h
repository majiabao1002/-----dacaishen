#import <UIKit/UIKit.h>
@interface RotateLoadCover : UIImageView
@property (nonatomic, strong) UIImage *originImage;
- (void)removeAfterDelay:(NSTimeInterval)delay;
@end
