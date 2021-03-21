//
//  ViewController.m
//  AVFoundationProject
//
//  Created by zhaohongbo on 2021/3/21.
//

#import "ViewController.h"
#define vedioTollBoxId @"vedioToolBox编码"
@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
/***/
@property (nonatomic,strong) UITableView *tableView;
/***/
@property (nonatomic,strong) NSMutableArray <NSString *>*dataArray;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataArray = @[vedioTollBoxId].mutableCopy;
    self.tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 44, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds)) style:UITableViewStyleGrouped];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];
    [self.view addSubview:self.tableView];
    
    
    
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataArray.count;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *string = self.dataArray[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
    
    cell.textLabel.text = string;
    return cell;;
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *string = self.dataArray[indexPath.row];
    if ([string isEqualToString:vedioTollBoxId]) {
        
    }
    
}

@end
