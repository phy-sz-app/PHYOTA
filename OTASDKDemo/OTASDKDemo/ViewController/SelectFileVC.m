//
//  SelectFileVC.m
//  OTASDKDemo
//
//  Created by 陈双超 on 2022/6/14.
//  Copyright © 2022 phy. All rights reserved.
//

#import "SelectFileVC.h"
#import "OTAListCell.h"


@interface SelectFileVC ()<UIDocumentInteractionControllerDelegate> {
    NSMutableArray *fileList;
    UIDocumentInteractionController *_documentController; //文档交互控制器
    NSString *docDirs;
}

@property (strong, nonatomic) NSMutableArray *documentArr;

@property (nonatomic, strong) NSMutableArray *selectArray;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation SelectFileVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.documentArr = [NSMutableArray array];
    self.selectArray = [NSMutableArray array];
    [self.tableView registerClass:[OTAListCell class] forCellReuseIdentifier:@"OTAListCell"];
    if (!self.isRepeat) {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_queue_t serialQueue = dispatch_queue_create("com.example.serialQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        [self setView];
        dispatch_async(dispatch_get_main_queue(), ^{
            // 更新界面
           [self.tableView reloadData];
        });
    });
}

- (void)setView {
    // 文件管理器
    NSFileManager *manager = [NSFileManager defaultManager];
    // 总文件夹
    NSString *folderPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/Inbox/"]];
    docDirs = folderPath;
    NSError *error = nil;
    //_dataFileArray是包含有该文件夹下所有文件的文件名及文件夹名的数组
    _documentArr = [[manager contentsOfDirectoryAtPath:docDirs error:&error] copy];
    fileList = [NSMutableArray array];
   
    if (![manager fileExistsAtPath:folderPath]) return;
    // 从前向后枚举器
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:folderPath] objectEnumerator];
    // 详细内容
    NSString *fileName = nil;
    OTCModel *fileObj = nil;
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        fileObj = [[OTCModel alloc] init];
        fileObj.fileName = fileName;
        NSDictionary *fileAttributes = [manager attributesOfItemAtPath:[docDirs stringByAppendingPathComponent:fileName] error:nil];
        fileObj.filemTime = [fileAttributes objectForKey:@"NSFileCreationDate"];
        fileObj.fileSize = [[fileAttributes objectForKey:@"NSFileSize"] integerValue];
        fileObj.fileOwner = [fileAttributes objectForKey:@"NSFileGroupOwnerAccountName"];//所有人
        fileObj.fileAbsolutePath = [folderPath stringByAppendingPathComponent:fileName];
        [fileList addObject:fileObj];
    }
}

- (IBAction)commitFileAction:(id)sender {
    if (self.selectArray.count > 0) {
        NSMutableArray *selectFileArray = [NSMutableArray array];
        for (NSIndexPath *item in self.selectArray) {
            OTCModel *model = [fileList objectAtIndex:item.row];
            [selectFileArray addObject:model];
        }
        if ([self.delegate respondsToSelector:@selector(selectedFile:)]) {
            [self.delegate selectedFile:selectFileArray];
        }
        [self.navigationController popViewControllerAnimated:YES];
    }else {
        UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"Tip" message:@"No File Selected!" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertC addAction:action];
        [self presentViewController:alertC animated:YES completion:nil];
    }
    
}

#pragma mark - UIDocumentInteractionControllerDelegate
- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    //注意：此处要求的控制器，必须是它的页面view，已经显示在window之上了
    return self.navigationController;
}


#pragma mark -- tableView设置

//设置tableview行
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return fileList.count;
}

//设置行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OTAListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OTAListCell" forIndexPath:indexPath];
    OTCModel *fileObj = (OTCModel *)[fileList objectAtIndex:indexPath.row];
    cell.contentLabel.text = fileObj.fileName;//文件名
    if ([self.selectArray containsObject:indexPath]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

//点击事件
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!self.isRepeat) {
        // 去除选中之后的效果
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        OTCModel *model = [fileList objectAtIndex:indexPath.row];
        if ([self.delegate respondsToSelector:@selector(selectedFile:)]) {
            [self.delegate selectedFile:@[model]];
        }
        [self.navigationController popViewControllerAnimated:YES];
    }else {
        if([self.selectArray containsObject:indexPath]) {
            [self.selectArray removeObject:indexPath];
        }else {
            [self.selectArray addObject:indexPath];
        }
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    
}

/**
 *  指定哪些行的cell可以进行编辑
 */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

/**
  *  指定cell的编辑状态
  */
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return  UITableViewCellEditingStyleDelete; //删除
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    //点击 删除 按钮的操作
    if (editingStyle == UITableViewCellEditingStyleDelete) {//判断编辑状态为删除时
        NSError *error = nil;
        if([[NSFileManager defaultManager] removeItemAtPath:((OTCModel *)fileList[indexPath.row]).fileAbsolutePath error:&error]) {
            //1. 更新数据源数组: 根据indexPath.row作为数组下标,从数组中删除数据
            [fileList removeObjectAtIndex:indexPath.row];
            //2. tableView中 删除一个cell
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            if([self.selectArray containsObject:indexPath]){
                [self.selectArray removeObject:indexPath];
            }
        }else {
            NSLog(@"error while removing file: %@", error.localizedDescription);
        }
    }
}
 


@end
