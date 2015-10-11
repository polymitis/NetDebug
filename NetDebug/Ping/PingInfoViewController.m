//
//  PingInfoViewController.m
//  NetDebug
//
//  Created by Petros Fountas on 09/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#import "AppDelegate.h"
#import "DataModel.h"

#import "PingInfoViewController.h"

@interface PingInfoViewController ()
<UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate, DataModelDelegateProtocol>

@property (strong, nonatomic) DataModel *dataModel;

@property (strong, nonatomic) PingOperation *ping;

@property (strong, nonatomic) NSArray *responses;

@property (weak, nonatomic) IBOutlet UILabel *dateLabel;

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property (weak, nonatomic) IBOutlet UILabel *commStatLabel;

@property (weak, nonatomic) IBOutlet UILabel *timeStatLabel;

@property (weak, nonatomic) IBOutlet UIScrollView
*packetsTableScrollView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*packetsTableScrollViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*packetsTableScrollViewAlignmentCenterXConstraint;

@property (weak, nonatomic) IBOutlet UITableView
*packetsTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*packetsTableViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*packetsTableViewHeightConstraint;

@end

@implementation PingInfoViewController

// adjust view to device
- (void)adjustViewToDevice
{
    CGFloat dx = 0;
    CGFloat dwidth = 0;
    CGFloat dheight = 0;
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    NSLog(@"Screen height: %.1f", screenHeight);
    
    // the following adjustment values were determined by experimentation
    if (screenHeight == 480) {
        NSLog(@"iPhone 4/4s detected");
        dx = 7.5;
        dwidth = 18;
        
    } else if (screenHeight == 568) {
        NSLog(@"iPhone 5/5s detected");
        dx = 7.5;
        dwidth = 18;
        dheight = 50;
        
    } else if (screenHeight == 667) {
        NSLog(@"iPhone 6 detected");
        dx = 7.5;
        dwidth = 74;
        dheight = 150;
    }
    
    // adjust packets table schroll view center x alignment to screen
    self.packetsTableScrollViewAlignmentCenterXConstraint.constant += dx;
    NSLog(@"Packets Table Scroll View center X alignment adjusted to %f\n",
          self.packetsTableScrollViewAlignmentCenterXConstraint.constant);
    
    // adjust packets table schroll view to screen
    self.packetsTableScrollViewWidthConstraint.constant += dwidth;
    NSLog(@"Packets Table Scroll View width adjusted to %f\n",
          self.packetsTableScrollViewWidthConstraint.constant);
    
    // adjust packets table view to screen
    self.packetsTableViewWidthConstraint.constant += dwidth;
    NSLog(@"Packets Table View width adjusted to %f\n",
          self.packetsTableViewWidthConstraint.constant);
    self.packetsTableViewHeightConstraint.constant += dheight;
    NSLog(@"Packets Table View height adjusted to %f\n",
          self.packetsTableViewHeightConstraint.constant);
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.packetsTableScrollView.delegate =self;
    self.packetsTableView.dataSource = self;
    self.packetsTableView.delegate = self;
    
    [self adjustViewToDevice]; // adjust this view and all subviews to device
    
    // read data model and update UI
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"MMM dd, yyyy HH:mm:ss"];
    self.dateLabel.text = [format stringFromDate:self.date];
    
    self.commStatLabel.text = [NSString stringWithFormat:
                               @"Send: %d packets, Received: %d packets",
                               [self.ping.numberOfPackets intValue],
                               (int)[self.responses count]];
    
    NSNumber *min_dt =
    [self.responses valueForKeyPath:@"@min.roundTripTime"];
    NSNumber *max_dt =
    [self.responses valueForKeyPath:@"@max.roundTripTime"];
    NSNumber *avg_dt =
    [self.responses valueForKeyPath:@"@avg.roundTripTime"];
    
    if ([self.responses count]) {
        PingResponse *response = [self.ping.responses anyObject];
        if (![self.dataModel performReverseDNSLookupOf:response.sourceAddress
                                              delegate:self]) {
            self.statusLabel.text = @"Unresolved IP Address"; // bug!
        } else {
            self.statusLabel.text = @"DNS Lookup in progress";
        }
        
        self.title = response.sourceAddress; // show the source address
        
        self.timeStatLabel.text =
        [NSString stringWithFormat:@"Min: %2.1f ms, Avg: %2.1f ms,"
         " Max: %2.1f ms",
         [min_dt doubleValue]*1e3,[avg_dt doubleValue]*1e3,
         [max_dt doubleValue]*1e3];
        
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setDate:(NSDate *)date
{
    if (date) {
        _date = date;
        self.ping = nil;
    }
}

- (DataModel *)dataModel
{
    if (!_dataModel) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        _dataModel = appDelegate.dataModel;
    }
    return _dataModel;
}


- (PingOperation *)ping
{
    if (!_ping) {
        // fetch the ping operation of the specified date
        NSFetchRequest *request =
        [NSFetchRequest fetchRequestWithEntityName:@"PingOperation"];
        request.predicate =
        [NSPredicate predicateWithFormat:@"date == %@", self.date];
        NSError *error;
        NSArray *results =
        [self.dataModel.context executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"Fetch of Ping Operation on %@ failed with error: %@",
                  self.date, error);
        } else if (![results count]) {
            NSLog(@"Ping Operation on %@ not found", self.date);
        } else {
            _ping = results[0];
            self.responses = nil;
        }
    }
    return _ping;
}

- (NSArray *)responses
{
    if (!_responses) {
        // fetch all responses of the ping operation
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:@"no"
                                      ascending:YES
                                       selector:@selector(compare:)];
        NSArray *sortDescriptors =
        [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        
        _responses =
        [[self.ping.responses
          sortedArrayUsingDescriptors:sortDescriptors] copy];
    }
    return _responses;
}

#pragma mark - Stations Scroll View Data Source

// restrict schrolling only to Y axis
- (void)scrollViewDidScroll:(UIScrollView *)aScrollView
{
    // disable horizontal schroll
    [aScrollView setContentOffset: CGPointMake(0, aScrollView.contentOffset.y)];
}

#pragma mark - Packets Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [self.responses count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier:@"cell"
                                    forIndexPath:indexPath];
    
    for (UIView *view in cell.contentView.subviews) {
        if (view.tag == 1) { // 1st view (Packet No)
            ((UILabel *)view).text =
            [NSString stringWithFormat:@"Packet %d",(int)indexPath.row+1];
        } else if (view.tag == 2) { // 2nd view (Round-Trip-Time)
            ((UILabel *)view).text =
            [NSString stringWithFormat:@"%2.2f ms",
             [((PingResponse *)self.responses[indexPath.row]).
              roundTripTime doubleValue]*1e3];
            
        }
    }
    
    return cell;
}

#pragma mark - DataModel Operation Delegate

- (void)dataModelOperation:(DataModelOperationType)type
     didSucceedWithContext:(NSManagedObjectContext *)context
{
    if (type == DataModelOperationTypeDNSLookup)
        self.statusLabel.text = self.dataModel.ip;
    else if (type == DataModelOperationTypeReverseDNSLookup)
        self.statusLabel.text = self.dataModel.host;
}

- (void)dataModelOperation:(DataModelOperationType)type didFailWithError:(NSError *)error
{
    if (type == DataModelOperationTypeReverseDNSLookup) {
        NSLog(@"Reverse DNS lookup operation failed!");
    
        // Handle error
        self.statusLabel.text = @"Unresolved IP Address";
    }
}

@end
