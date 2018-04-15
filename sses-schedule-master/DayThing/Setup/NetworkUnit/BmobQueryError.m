#import "BmobQueryError.h"
@implementation BmobQueryError
-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        [self makeUI];
    }
    return self;
}
-(void)makeUI
{
    UILabel *lable = [[UILabel alloc]initWithFrame:CGRectMake(100, 250, self.frame.size.width-200, 40)];
    lable.textAlignment = NSTextAlignmentCenter;
    lable.text = NSLocalizedString(@"网络发生错误",@"");
    [self addSubview:lable];
    self.btn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btn.frame = CGRectMake(100, 300, self.frame.size.width-200, 40);
    [self.btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.btn.layer.borderWidth = 1;
    self.btn.layer.borderColor = [[UIColor blackColor] CGColor];
    [self.btn setTitle:@"点击重试" forState:UIControlStateNormal];
    [self addSubview:self.btn];
}
@end
