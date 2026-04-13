//
//  bluetoothListViewController.m
//  PHY
//
//  Created by Han on 2018/9/28.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "SelectDeviceVC.h"
#import "BluetoothListCell.h"
#import "PopupMenuView.h"
#import "SelectFileVC.h"
#import "BluetoothLogVC.h"

@interface SelectDeviceVC ()<UITableViewDelegate, UITableViewDataSource, PHYBLEManagerDelegate, PopupMenuViewDelegate, SelectFileDelegate>

@property (nonatomic, weak) PHYBLEManager            *bluetoothManager;

@property (nonatomic, strong) NSMutableArray         *showArray;//显示数据，排序后的周边设备
@property (nonatomic, strong) NSMutableArray         *selectArray; //保存的是UUIDString

@property (weak, nonatomic) IBOutlet UITableView     *tableView;
@property (assign, nonatomic) BOOL showScanOrUpgrade; //YES：显示扫描页面；NO 显示升级页面的数据

@property (weak, nonatomic) IBOutlet UIBarButtonItem *rightBarButton;

@property (weak, nonatomic) IBOutlet UILabel *showTip;

@property (weak, nonatomic) IBOutlet UIButton *StartOTAButton;

@property (nonatomic, strong) NSString *productIDAndVersion;

@property (nonatomic, strong) NSMutableArray *bluetoothLogArray;

@end

@implementation SelectDeviceVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        appearance.backgroundColor = [UIColor colorWithRed:0 green:0x9c/255.0 blue:0x3a/255.0 alpha:1];
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.standardAppearance = appearance;
    }
    
    [self.tableView registerNib:[UINib nibWithNibName:@"BluetoothListCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"BluetoothListCell"];
    
    //蓝牙初始化
    self.bluetoothManager = [PHYBLEManager shareInstance];
    self.bluetoothManager.delegate = self;
    self.showArray = [NSMutableArray array];
    self.selectArray = [NSMutableArray array];
    self.bluetoothLogArray = [NSMutableArray array];
    
}

- (void)addLogWithMessage:(NSString *)message code:(NSUInteger)code device:(NSString *)device type:(NSString *)type {
    NSDate *now = [NSDate date];
    NSDictionary *logEntry = @{
        @"timestamp": now,
        @"message": message ?: @"",
        @"code": @(code),
        @"device": device ?: @"",
        @"type": type ?: @""
    };
    // 确保在主线程添加，因为委托回调可能在后台线程
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bluetoothLogArray addObject:logEntry];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.bluetoothManager.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    //离开页面前检查扫描是否已经停止
    [self stopScanAction];
    [super viewWillDisappear:animated];
}

- (IBAction)leftBarButtonAction:(UIBarButtonItem *)sender {
    CGFloat x = 8 ;
    CGFloat y = self.StartOTAButton.frame.origin.y-16;
    PopupMenuView *outputView = [[PopupMenuView alloc] initWithDataArray:@[@"交互日志",@"已连接OTA"] origin:CGPointMake(x, y) width:125 height:44 ];
    outputView.delegate = self;
    [outputView pop];
}


- (IBAction)rightBarButtonAction:(UIBarButtonItem *)sender {
    self.showScanOrUpgrade = YES;
    if([self.rightBarButton.title isEqualToString:NSLocalizedString(@"Stop", @"停止")]){
        [self stopScanAction];
    }else{
        [self startScanAction];
    }
}

- (IBAction)selectFileAction:(UIButton *)sender {
    [self performSegueWithIdentifier:@"selectFile" sender:nil];
}

- (IBAction)upgradeAction:(UIButton *)sender {
    UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"Tip" message:[NSString stringWithFormat:@"A total of %lu devices were selected!",(unsigned long)self.selectArray.count] preferredStyle:UIAlertControllerStyleAlert];
    if (self.selectArray.count > 0) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL isAddOK = [self.bluetoothManager addDevices:self.selectArray];
            if (isAddOK) {
                self.navigationItem.rightBarButtonItem.enabled = NO;
                self.showScanOrUpgrade = NO;
            }
        }];
        [alertC addAction:action];
    }
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
    [alertC addAction:cancel];
    [self presentViewController:alertC animated:YES completion:nil];
}

- (void)startScanAction {
    [self.selectArray removeAllObjects];
    self.rightBarButton.title = NSLocalizedString(@"Stop", @"停止扫描");
    if (self.bluetoothManager.myCentralManager.state==CBManagerStatePoweredOn && !self.bluetoothManager.myCentralManager.isScanning) {
        self.showTip.text = NSLocalizedString(@"ScanStarted", @"扫描已开始");
        [self.bluetoothManager startScan];
    }
}

- (void)stopScanAction {
    self.rightBarButton.title = NSLocalizedString(@"Scan", @"开始扫描");
    if (self.bluetoothManager.myCentralManager.state==CBManagerStatePoweredOn && self.bluetoothManager.myCentralManager.isScanning) {
        self.showTip.text = NSLocalizedString(@"ScanStopped", @"扫描已停止");
        [self.bluetoothManager stopScan];
    }
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"selectFile"]) {
        SelectFileVC *vc = (SelectFileVC *)segue.destinationViewController;
        vc.delegate = self;
        vc.isRepeat = NO;
    }
}

#pragma mark -- tableView设置

//设置tableview行
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.showArray.count;
}

//设置行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BluetoothListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BluetoothListCell" forIndexPath:indexPath];
    [cell setBlutoothInfo:self.showArray[indexPath.row] isScan:self.showScanOrUpgrade];
    if (self.showScanOrUpgrade) {
        NSString *selectStr = ((PHYBLEModel *)self.showArray[indexPath.row]).peripheral.identifier.UUIDString;
        cell.mSelected = [self.selectArray containsObject:selectStr];
    }else {
        cell.mSelected = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

//点击事件
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self stopScanAction];
    PHYBLEModel *model = self.showArray[indexPath.row];
    if([self.selectArray containsObject:model.peripheral.identifier.UUIDString]) {
        [self.selectArray removeObject:model.peripheral.identifier.UUIDString];
    }else {
        [self.selectArray addObject:model.peripheral.identifier.UUIDString];
    }
    [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    
}

/**
 *  指定哪些行的cell可以进行编辑
 */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// 自定义左滑显示编辑按钮
- (NSArray<UITableViewRowAction*>*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self stopScanAction];
    UITableViewRowAction *rowAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Custom alias" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self setNameAlert:indexPath];
    }];
   
    rowAction.backgroundColor = [UIColor blueColor];
    NSArray *arr = @[rowAction];
    return arr;
}

- (void)setNameAlert:(NSIndexPath *)indexPath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom device alias" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    PHYBLEModel *model = self.showArray[indexPath.row];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *keyValue = alert.textFields.firstObject;
        if(keyValue.text.length > 0) {
            self.showTip.text = [NSString stringWithFormat:@"New alias:%@！",keyValue.text];
            [[NSUserDefaults standardUserDefaults] setObject:keyValue.text forKey:model.peripheral.identifier.UUIDString];
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }else{
            self.showTip.text = @"Alias cannot be empty！";
        }
    }]];
    [alert addTextFieldWithConfigurationHandler:^(UITextField*_Nonnull textField) {
        textField.placeholder = @"Please enter the alias ";
    }];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - PopupMenuViewDelegate

- (void)didSelectedAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"选择第%ld行",(long)indexPath.row);
    if(indexPath.row == 0){
        [self gotoLogsVC];
    }else if (indexPath.row == 1){
        [self performSegueWithIdentifier:@"demovc" sender:nil];
    }
}

- (void)gotoLogsVC {
    BluetoothLogVC *logVC = [[BluetoothLogVC alloc] init];
    logVC.logArray = self.bluetoothLogArray;
    [self.navigationController pushViewController:logVC animated:YES];
}


#pragma mark - SDK回调相关代理方法

- (void)deviceFound:(NSArray *)devicesArray {
    if (self.showScanOrUpgrade) {
        self.showArray = [devicesArray mutableCopy];
        [self.tableView reloadData];
    }
    // 记录日志
    NSString *message = [NSString stringWithFormat:@"发现设备数量：%lu", (unsigned long)devicesArray.count];
    [self addLogWithMessage:message code:0 device:@"" type:@"deviceFound"];

}

- (void)centerMessage:(NSString *)message code:(NSUInteger)code {
    self.showTip.text = message;
    // 记录日志
    [self addLogWithMessage:message code:code device:@"" type:@"centerMessage"];
    if (code == BLENOTActive) {
        NSLog(@"%@",message);
        [self stopScanAction];
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }else if(code == BLEActive) {
//        [self startScanAction];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }else if (code == FileVersion){
        self.productIDAndVersion = message;
    }else if(code == OTAEnd) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [self showAlert:message];
    }
    
}

- (void)listenNotify:(CBPeripheral *)peripheral message:(NSString *)message code:(NSUInteger)code {
    NSLog(@"%@ -- %@",peripheral.name, message);
    self.showTip.text = [NSString stringWithFormat:@"%@ -- %@",peripheral.name, message];
    // 记录日志
    NSString *deviceName = peripheral.name ?: @"";
    [self addLogWithMessage:message code:code device:deviceName type:@"listenNotify"];
    self.showArray = [self.bluetoothManager.deviceArray mutableCopy];
    [self.tableView reloadData];
    
    if (code == DeviceVersion) {
        NSString *titleStr = [NSString stringWithFormat:@"文件版本：%@，设备固件版本：%@",self.productIDAndVersion,message];
        NSLog(@"%@", titleStr);
    }else if(code == ProgressCallBack) {
//        float value = [message floatValue];
//        NSLog(@"自定义进度值，Custom progress value: %.2f",value);
    }
}

#pragma mark - 选择文件代理方法

- (void)selectedFile:(NSArray *)fileModelArray {
    
    NSString *fileStr = @"";
    for (int i=0; i<fileModelArray.count; i++) {
        OTCModel *modelTemp = fileModelArray[i];
        fileStr = [fileStr stringByAppendingString:modelTemp.fileName];
        fileStr = [fileStr stringByAppendingString:@" "];
    }
    self.showTip.text = fileStr;
    
    OTCModel *fileModel = fileModelArray[0];
    [self.bluetoothManager selectFilePath:fileModel.fileAbsolutePath];
    self.StartOTAButton.enabled = true;
    
}

- (void)showAlert:(NSString *)message {
    
    UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"Tip" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertC addAction:action];
    [self presentViewController:alertC animated:YES completion:nil];
    
}


@end
