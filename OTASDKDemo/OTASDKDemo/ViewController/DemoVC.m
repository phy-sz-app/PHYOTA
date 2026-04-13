//
//  DemoVC.m
//  OTASDKDemo
//
//  Created by di lu on 2022/8/1.
//  Copyright © 2022 phy. All rights reserved.
//

#import "DemoVC.h"
#import "SelectFileVC.h"

#define StepOne     @"扫描设备"
#define StepTwo     @"开始升级"

@interface DemoVC ()<CBCentralManagerDelegate, CBPeripheralDelegate, PHYBLEManagerDelegate, UITableViewDataSource, UITableViewDelegate, SelectFileDelegate>

@property (nonatomic, strong) CBCentralManager *mCentralManager;
@property (nonatomic, strong) CBPeripheral *mPeripheral;
// 扫描到的设备数组
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *discoveredPeripherals;

@property (nonatomic, weak) PHYBLEManager  *bluetoothManager;

@property (weak, nonatomic) IBOutlet UILabel *showLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
// 设备列表
@property (weak, nonatomic) IBOutlet UITableView *deviceTableView;

@end

@implementation DemoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化数组
    self.discoveredPeripherals = [NSMutableArray array];
    
    // 表格设置
    self.deviceTableView.dataSource = self;
    self.deviceTableView.delegate = self;
    self.deviceTableView.hidden = YES; // 默认隐藏
    
    // 蓝牙初始化
    self.mCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.bluetoothManager = [PHYBLEManager shareInstance];
    
    // 初始UI
    self.stopButton.hidden = YES;
    [self.startButton setTitle:StepOne forState:UIControlStateNormal];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.mCentralManager.isScanning) {
        [self.mCentralManager stopScan];
    }
    [self.bluetoothManager stopOTA];
}

- (IBAction)startAction:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:StepOne]) {
        // 清空旧设备
        [self.discoveredPeripherals removeAllObjects];
        [self.deviceTableView reloadData];
        
        // 显示列表、开始扫描
        self.deviceTableView.hidden = NO;
        self.showLabel.text = @"扫描中...，请选择设备进行连接";
        self.mCentralManager.delegate = self;
        [self.mCentralManager scanForPeripheralsWithServices:nil options:nil];
        
    } else if ([sender.titleLabel.text isEqualToString:StepTwo]) {
        // 开始升级
        self.startButton.hidden = YES;
        self.stopButton.hidden = NO;
        self.showLabel.text = @"开始升级！";
        
        self.bluetoothManager.myCentralManager = _mCentralManager;
        self.bluetoothManager.delegate = self;
        
        [self.bluetoothManager connectedDeviceOTA:self.mPeripheral];
    }
}

- (IBAction)stopAction:(id)sender {
    [self.startButton setTitle:StepOne forState:UIControlStateNormal];
    self.startButton.hidden = NO;
    self.stopButton.hidden = YES;
    
    [self.bluetoothManager stopOTA];
}

- (IBAction)selectFileAction:(id)sender {
    [self performSegueWithIdentifier:@"selectFile" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"selectFile"]) {
        SelectFileVC *vc = (SelectFileVC *)segue.destinationViewController;
        vc.delegate = self;
        vc.isRepeat = NO;
    }
}

#pragma mark - 蓝牙扫描 & 连接
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        NSLog(@"蓝牙已开启");
    } else {
        self.showLabel.text = @"请开启手机蓝牙";
        NSLog(@"蓝牙不可用");
    }
}

// 发现设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    // 过滤无名称设备（可自行注释）
    if (!peripheral.name || peripheral.name.length == 0) return;
    
    // 去重添加
    if (![self.discoveredPeripherals containsObject:peripheral]) {
        [self.discoveredPeripherals addObject:peripheral];
        [self.deviceTableView reloadData];
    }
}

// 连接成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"设备连接成功");
    
    self.mPeripheral = peripheral;
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    
    self.showLabel.text = @"连接成功，点击开始升级";
    [self.startButton setTitle:StepTwo forState:UIControlStateNormal];
    self.deviceTableView.hidden = YES;
}

// 连接失败/断开
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.showLabel.text = @"已断开连接，请重新扫描";
    [self.startButton setTitle:StepOne forState:UIControlStateNormal];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error { }

#pragma mark - UITableView 设备列表
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.discoveredPeripherals.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"DeviceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    CBPeripheral *p = self.discoveredPeripherals[indexPath.row];
    cell.textLabel.text = p.name ?: @"未知设备";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 停止扫描
    [self.mCentralManager stopScan];
    // 取出选中设备
    CBPeripheral *peripheral = self.discoveredPeripherals[indexPath.row];
    self.showLabel.text = [NSString stringWithFormat:@"正在连接：%@", peripheral.name];
    
    // 连接设备
    [self.mCentralManager connectPeripheral:peripheral options:nil];
}

#pragma mark - PHYBLEManagerDelegate
- (void)listenNotify:(CBPeripheral *)peripheral message:(NSString *)message code:(NSUInteger)code {
    NSLog(@"收到消息：%@",message);
    self.showLabel.text = message;
}

- (void)centerMessage:(NSString *)message code:(NSUInteger)code {
    NSLog(@"收到消息：%@",message);
    self.showLabel.text = message;
    
    if(code == OTAEnd || code == FileError) {
        [self.startButton setTitle:StepOne forState:UIControlStateNormal];
        self.startButton.hidden = NO;
        self.stopButton.hidden = YES;
    }
}

- (void)deviceFound:(NSArray *)devicesArray {}

#pragma mark - 选择文件代理方法

- (void)selectedFile:(NSArray *)fileModelArray {
    
    NSString *fileStr = @"";
    for (int i=0; i<fileModelArray.count; i++) {
        OTCModel *modelTemp = fileModelArray[i];
        fileStr = [fileStr stringByAppendingString:modelTemp.fileName];
        fileStr = [fileStr stringByAppendingString:@" "];
    }
    self.showLabel.text = fileStr;
    
    OTCModel *fileModel = fileModelArray[0];
    NSLog(@"选择升级文件：%@",fileModel.fileAbsolutePath);
    
    self.bluetoothManager.delegate = self;
    [self.bluetoothManager selectFilePath:fileModel.fileAbsolutePath];
    
    
}

@end
