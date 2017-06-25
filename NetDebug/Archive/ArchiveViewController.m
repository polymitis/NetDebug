//
//  ArchiveViewController.m
//  NetDebug
//
//  Created by Petros Fountas on 10/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#import "AppDelegate.h"
#import "DataModel.h"
#import "PingInfoViewController.h"
#import "TraceInfoViewController.h"

#import "ArchiveViewController.h"

@interface ArchiveViewController ()
<UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) DataModel *dataModel;

@property (strong, nonatomic) NSArray *traceOperations;

@property (strong, nonatomic) NSArray *pingOperations;

@property (nonatomic, getter=isTableDataReloadedAfterDataUpdate) BOOL
updateTableAfterDataUpdate;

@end

@implementation ArchiveViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.updateTableAfterDataUpdate = YES;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(updateData)
     name:[DataModel dataModelUpdatedNotification]
     object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (DataModel *)dataModel
{
    if (!_dataModel) {
        AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        _dataModel = appDelegate.dataModel;
    }
    return _dataModel;
}

- (NSArray *)pingOperations
{
    return self.dataModel.pingOperations;
}

- (void)setPingOperations:(NSArray *)pingOperations
{
    self.dataModel.pingOperations = pingOperations;
}

- (NSArray *)traceOperations
{
    return self.dataModel.traceOperations;
}

- (void)setTraceOperations:(NSArray *)traceOperations
{
    self.dataModel.pingOperations = traceOperations;
}

// upaded the table data after forcing the data model to reload
- (void)updateData
{
    [self invalidateData];
    if (self.isTableDataReloadedAfterDataUpdate)
        [self.tableView reloadData];
}

// forces data model reloading
- (void)invalidateData
{
    self.pingOperations = nil;
    self.traceOperations = nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (section == 0) { // Ping Operations
        return [self.pingOperations count];
    } else { // Trace Operations
        return [self.traceOperations count];
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier:@"cell"
                                    forIndexPath:indexPath];
    
    UIImage *icon;
    NSString *title = @"";
    NSString *detail = @"";
    if (indexPath.section == 0) { // Ping Operation
        PingOperation *operation = self.pingOperations[indexPath.row];
        title = operation.target;
        
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"dd/MM/yy"];
        detail = [format stringFromDate:operation.date];
        
        icon = [UIImage imageNamed:@"Ping Tab Icon"];
        
    } else { // Trace Operation
        TraceOperation *operation = self.traceOperations[indexPath.row];
        title = operation.target;
        
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"dd/MM/yy"];
        detail = [format stringFromDate:operation.date];
        
        icon = [UIImage imageNamed:@"Trace Tab Icon"];
    }
    
    // setup cell
    for (UIView *view in cell.contentView.subviews) {
        if (view.tag == 1) {
            UILabel *titleLabel = (UILabel *)view;
            titleLabel.text = title;
            
        } else if (view.tag == 2) {
            UILabel *detailLabel = (UILabel *)view;
            detailLabel.text = detail;
            
        } else if (view.tag == 3) {
            UIImageView *iconView = (UIImageView *)view;
            iconView.image = icon;
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // choose segue depending on the operation
    if (indexPath.section == 0) // Ping operation
        [self performSegueWithIdentifier:@"PingInfoSegue"
                                  sender:self.pingOperations[indexPath.row]];
    else // Trace operation
        [self performSegueWithIdentifier:@"TraceInfoSegue"
                                  sender:self.traceOperations[indexPath.row]];
}

- (BOOL)tableView:(UITableView *)tableView
canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        self.updateTableAfterDataUpdate = NO; // deactive autoupdate for table
        
        if (indexPath.section == 0) {
            [self.dataModel
             deleteOperation:self.pingOperations[indexPath.row]];
        } else {
            [self.dataModel
             deleteOperation:self.traceOperations[indexPath.row]];
        }
        
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
        
        self.updateTableAfterDataUpdate = YES; // reactive autoupdate for table
    }
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UIViewController *dvc = [segue destinationViewController];
    
    if ([dvc isMemberOfClass:[PingInfoViewController class]]
        && [sender isMemberOfClass:[PingOperation class]]) { // ping
        PingInfoViewController *pivc = (PingInfoViewController *)dvc;
        pivc.date = ((PingOperation *)sender).date; // set date of ping
        
    } else if ([dvc isMemberOfClass:[TraceInfoViewController class]]
              && [sender isMemberOfClass:[TraceOperation class]]) { // trace
        TraceInfoViewController *tivc = (TraceInfoViewController *)dvc;
        tivc.date = ((TraceOperation *)sender).date; // set date of trace
    }
}


@end
