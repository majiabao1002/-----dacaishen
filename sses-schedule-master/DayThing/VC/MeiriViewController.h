//
//  MeiriViewController.h
//
//
//  Created by Eric Liang on 8/2/12.
//
//

#import <UIKit/UIKit.h>

@interface MeiriViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISegmentedControl *upper_middle_segment;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIView *upperContentView;
@property (nonatomic, strong) IBOutlet UIView *middleContentView;

@end
