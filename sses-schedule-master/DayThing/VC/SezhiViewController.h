//
//  SezhiViewController.h
//
//
//  Created by Eric Liang on 11/17/12.
//
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>


@interface SezhiViewController : UIViewController<UITableViewDelegate,UITableViewDataSource>


@property (nonatomic, strong)IBOutlet UITableView *myTableView;
@property (nonatomic, strong)NSMutableArray *users;
@property (nonatomic, strong)NSIndexPath *lastIndexPath;

@property (nonatomic, strong)UIBarButtonItem *addBarItem;
@property (nonatomic, strong)UIBarButtonItem *backBarItem;
@property (nonatomic, strong)UIBarButtonItem *doneBarItem;
@property (nonatomic, strong)UIBarButtonItem *editBarItem;

@end
