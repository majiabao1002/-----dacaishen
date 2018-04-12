//
//  FirstWelcomeViewController.h
//
//
//  Created by Eric Liang on 11/18/12.
//
//

#import <UIKit/UIKit.h>

@interface DiyiHuanyingViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISegmentedControl *schoolSectionSegment;

@property (strong, nonatomic) IBOutlet UIButton *doneButton;


- (IBAction)schoolSectionValueChanged:(UISegmentedControl *)sender;
- (IBAction)buttonPressed:(UIButton *)sender;
@end
