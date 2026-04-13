//
//  BluetoothLogVC.m
//  OTASDKDemo
//
//  Created by di lu on 2026/4/7.
//  Copyright © 2026 phy. All rights reserved.
//

#import "BluetoothLogVC.h"

@interface BluetoothLogVC () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation BluetoothLogVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"蓝牙交互日志";
    [self setupTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    // 注册默认单元格
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.logArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont systemFontOfSize:12];

    // 反转顺序，最新的在最上面
    NSInteger reversedIndex = self.logArray.count - 1 - indexPath.row;
    NSDictionary *logEntry = self.logArray[reversedIndex];
    NSDate *timestamp = logEntry[@"timestamp"];
    NSString *message = logEntry[@"message"];
    NSNumber *code = logEntry[@"code"];
    NSString *device = logEntry[@"device"];
    NSString *type = logEntry[@"type"];

    // 格式化时间
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *timeStr = [formatter stringFromDate:timestamp];

    // 构建显示文本
    NSString *displayText = [NSString stringWithFormat:@"[%@] %@\n设备: %@ 类型: %@ 代码: %@",
                             timeStr, message, device, type, code];
    cell.textLabel.text = displayText;

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 自动计算高度
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

@end