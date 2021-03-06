//
//  FirstWelcomeViewController.m
//
//
//  Created by Eric Liang on 11/18/12.
//
//

#import "DiyiHuanyingViewController.h"
#import "Common.h"
@interface DiyiHuanyingViewController ()

@end

@implementation DiyiHuanyingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization    [[GameDetailDataComposer new] loadDataWithBlock:nil];
        [NSArray new];
        [NSMutableDictionary new];
        [NSArray new];
        [NSString new];
        
        [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
        
        [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.doneButton.layer setBorderColor:[UIColor whiteColor].CGColor];
    self.doneButton.layer.borderWidth = 1.0;
    self.doneButton.layer.cornerRadius = 5;
    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)schoolSectionValueChanged:(UISegmentedControl *)sender {
    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

    [UIView beginAnimations:@"show done" context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView setAnimationBeginsFromCurrentState:YES];
    self.doneButton.alpha = 1.0;
    [UIView commitAnimations];
}

- (IBAction)buttonPressed:(UIButton *)sender {
    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

    SET_USER_DEFAULT([NSNumber numberWithInteger:self.schoolSectionSegment.selectedSegmentIndex], kUserDefaultsKeyUserTypeSchoolSection);

    NSDictionary *dictionary = GENERATE_USER_DATA_DICTIONARY([NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"emptyUserData" withExtension:@"plist"]], CURRENT_USER_NAME, SCHOOL_SECTION, PERSON_TYPE);
    NSString *filePath = PATH_FOR_DATA_OF_USER(CURRENT_USER_NAME);
    [dictionary writeToFile:filePath atomically:YES];
    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

    
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
