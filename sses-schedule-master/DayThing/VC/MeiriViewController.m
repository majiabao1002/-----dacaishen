//
//  MeiriViewController.m
//
//
//  Created by Eric Liang on 8/2/12.
//
//

#import "MeiriViewController.h"
#import "Common.h"
@interface MeiriViewController ()

@end

@implementation MeiriViewController
@synthesize upper_middle_segment;
@synthesize scrollView = _scrollView;
@synthesize upperContentView = _upperContentView;
@synthesize middleContentView = _middleContentView;

static CGRect upperViewFrame;
static CGRect middleViewFrame;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        [[GameDetailDataComposer new] loadDataWithBlock:nil];
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
    
    upperViewFrame=CGRectMake(0, 50, self.view.bounds.size.width, 870);
    middleViewFrame=CGRectMake(0, 50, self.view.bounds.size.width, 792);

    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

    CGSize upperViewSize = self.upperContentView.bounds.size;
    //CGSize middleViewSize = self.middleContentView.bounds.size;
    self.upperContentView.frame = upperViewFrame;
    self.middleContentView.frame= middleViewFrame;
    
    [self.scrollView addSubview:self.upperContentView];
    self.scrollView.contentSize = upperViewSize;
    
    [upper_middle_segment setTitle:NSLocalizedString(@"Upper",nil) forSegmentAtIndex:0];
    [upper_middle_segment setTitle:NSLocalizedString(@"Middle",nil) forSegmentAtIndex:1];
    
    self.title = NSLocalizedString(@"Daily Calendar", nil);
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];

    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

	// Do any additional setup after loading the view.
  
    upper_middle_segment.selectedSegmentIndex=0;
    
}

-(IBAction)upperLowerValueChange:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0://choose upper
            if (self.middleContentView.superview!=nil) {
                [self.middleContentView removeFromSuperview];
            }
            CGSize upperViewSize = self.upperContentView.bounds.size;
            [self.scrollView addSubview:self.upperContentView];
            self.scrollView.contentSize = upperViewSize;
            break;
            
        case 1://choose middle
            if (self.upperContentView.superview!=nil) {
                [self.upperContentView removeFromSuperview];
            }
            CGSize middleViewSize = self.middleContentView.bounds.size;
            [self.scrollView addSubview:self.middleContentView];
            self.scrollView.contentSize = middleViewSize;
            break;
    }
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{    [[GameDetailDataComposer new] loadDataWithBlock:nil];
    [NSArray new];
    [NSMutableDictionary new];
    [NSArray new];
    [NSString new];
    
    [[PubSearchDataComposer new] loadSuggestionWithCompletionBlock:nil];
    
    [[WriterDataComposer new] loadWithType:MMLoadTypeMore completionBlock:nil];

    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
