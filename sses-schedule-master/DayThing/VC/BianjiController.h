//
//  BianjiController.h
//
//
//
//
//

#import <UIKit/UIKit.h>
//#import "MarqueeLabel.h"
#import "FenleiXuanzeQiController.h"
@interface BianjiController : UIViewController<UITableViewDelegate,UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UITableView *editingTableView;
@property (strong, nonatomic) NSMutableDictionary *editedSchedule;
@property (strong, nonatomic) NSString *editingDayDisplayedName;
@property (strong, nonatomic) NSMutableDictionary *currentEditedDaySchedule;

@property (strong, nonatomic) NSDictionary * editedDataFromPicker;
@property (strong, nonatomic) NSNumber *isEdited;
@property (strong, nonatomic) IBOutlet UINavigationItem *editNavigationItem;
@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutletCollection(UIBarButtonItem) NSArray *letterButtons;


@property (strong, nonatomic) id delegate;

-(void)saveData;

-(IBAction)saveButtonPressed:(id)sender;

-(IBAction)dayButtonPressed:(UIButton *)sender;

//-(NSString *)dataFilePath;

@end
