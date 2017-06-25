//
//  TraceInfoViewController.m
//  NetDebug
//
//  Created by Petros Fountas on 10/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#import "AppDelegate.h"
#import "DataModel.h"
#import "PingInfoViewController.h"

#import "TraceInfoViewController.h"

@interface TraceInfoViewController ()
<UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate,
DataModelDelegateProtocol>

@property (strong, nonatomic) DataModel *dataModel;

@property (strong, nonatomic) TraceOperation *trace;

@property (strong, nonatomic) NSArray *stations;

@property (weak, nonatomic) IBOutlet UILabel *dateLabel;

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property (weak, nonatomic) IBOutlet UIScrollView
*stationsTableScrollView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*stationsTableScrollViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*stationsTableScrollViewAlignmentCenterXConstraint;

@property (weak, nonatomic) IBOutlet UITableView
*stationsTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*stationsTableViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint
*stationsTableViewHeightConstraint;

@end

@implementation TraceInfoViewController

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
    
    // adjust stations table schroll view center x alignment to screen
    self.stationsTableScrollViewAlignmentCenterXConstraint.constant += dx;
    NSLog(@"Stations Table Scroll View center X alignment adjusted to %f\n",
          self.stationsTableScrollViewAlignmentCenterXConstraint.constant);
    
    // adjust stations table schroll view to screen
    self.stationsTableScrollViewWidthConstraint.constant += dwidth;
    NSLog(@"Stations Table Scroll View width adjusted to %f\n",
          self.stationsTableScrollViewWidthConstraint.constant);
    
    // adjust stations table view to screen
    self.stationsTableViewWidthConstraint.constant += dwidth;
    NSLog(@"Stations Table View width adjusted to %f\n",
          self.stationsTableViewWidthConstraint.constant);
    self.stationsTableViewHeightConstraint.constant += dheight;
    NSLog(@"Stations Table View height adjusted to %f\n",
          self.stationsTableViewHeightConstraint.constant);
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.stationsTableScrollView.delegate =self;
    self.stationsTableView.dataSource = self;
    self.stationsTableView.delegate = self;
    
    [self adjustViewToDevice]; // adjust this view and all subviews to device
    
    // update UI
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"MMM dd, yyyy HH:mm:ss"];
    self.dateLabel.text = [format stringFromDate:self.date];
    
    if ([self.stations count]) {
        PingOperation *ping = [self.trace.pings anyObject];
        if (![self.dataModel performReverseDNSLookupOf:ping.target
                                              delegate:self]) {
            self.statusLabel.text = @"Unresolved IP Address"; // bug!
        } else {
            self.statusLabel.text = @"DNS Lookup in progress";
        }
        
        self.title = ping.target;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)setDate:(NSDate *)date
{
    if (date) {
        _date = date;
        self.trace = nil;
    }
}

- (DataModel *)dataModel
{
    if (!_dataModel) {
        AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        _dataModel = appDelegate.dataModel;
    }
    return _dataModel;
}

- (TraceOperation *)trace
{
    if (!_trace) {
        // fetch the trace operation of the specified date
        NSFetchRequest *request =
        [NSFetchRequest fetchRequestWithEntityName:@"TraceOperation"];
        request.predicate =
        [NSPredicate predicateWithFormat:@"date == %@", self.date];
        NSError *error;
        NSArray *results =
        [self.dataModel.context executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"Fetch of Trace Operation on %@ failed with error: %@",
                  self.date, error);
        } else if (![results count]) {
            NSLog(@"Trace Operation on %@ not found", self.date);
        } else {
            _trace = results[0];
            self.stations = nil;
        }
    }
    return _trace;
}


- (NSArray *)stations
{
    if (!_stations) {
        // fetch of intermediate stations (pings) of the trace operation
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:@"date"
                                      ascending:YES
                                       selector:@selector(compare:)];
        NSArray *sortDescriptors =
        [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        
        _stations =
        [[self.trace.pings
          sortedArrayUsingDescriptors:sortDescriptors] copy];
    }
    return _stations;
}

#pragma mark - Stations Scroll View Data Source

// restrict schrolling only to Y axis
- (void)scrollViewDidScroll:(UIScrollView *)aScrollView
{
    // disable horizontal schroll
    [aScrollView setContentOffset: CGPointMake(0, aScrollView.contentOffset.y)];
}

#pragma mark - Stations Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [self.stations count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier:@"cell"
                                    forIndexPath:indexPath];
    
    PingOperation *ping = self.stations[indexPath.row];
    PingResponse *response = [ping.responses anyObject];
    UIButton *infoButton;
    for (UIView *view in cell.contentView.subviews) {
        if (view.tag == 1) { // Address Label
            NSString *brief = @"N/A";
            if (response.sourceAddress) {
                // average response time
                NSNumber *avg_dt =
                [ping.responses valueForKeyPath:@"@avg.roundTripTime"];
                // station label
                brief = [NSString stringWithFormat:@"%@ (%2.2f)",
                         response.sourceAddress, [avg_dt doubleValue]*1e3];
            }
            ((UILabel *)view).text = [NSString stringWithFormat:@"[%d] %@",
                                      (int)indexPath.row+1, brief];
        } else if ([view isMemberOfClass:[UIButton class]]) { // Info Button
            infoButton = (UIButton *)view;
        }
    }
    infoButton.enabled = NO;
    if (response)
        infoButton.enabled = YES;
    
    return cell;
}

#pragma mark - Data Model Operation Delegate

- (void)dataModelOperation:(DataModelOperationType)type
     didSucceedWithContext:(NSManagedObjectContext *)context
{
    if (type == DataModelOperationTypeDNSLookup)
        self.statusLabel.text = self.dataModel.ip;
    else if (type == DataModelOperationTypeReverseDNSLookup)
        self.statusLabel.text = self.dataModel.host;
}

- (void)dataModelOperation:(DataModelOperationType)type
          didFailWithError:(NSError *)error
{
    if (type == DataModelOperationTypeReverseDNSLookup) {
        NSLog(@"Reverse DNS lookup operation failed!");
        
        // Handle error
        self.statusLabel.text = @"Unresolved IP Address";
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIViewController *dvc = [segue destinationViewController];
    
    if ([dvc isMemberOfClass:[PingInfoViewController class]]
        && [sender isMemberOfClass:[UIButton class]]) {
        PingInfoViewController *pivc = (PingInfoViewController *)dvc;
        pivc.date = nil;
        UIButton *infoButton = sender;
        UIView *cellContextView = infoButton.superview;
        for (UIView *view in cellContextView.subviews) {
            if (view.tag == 1) {
                
                NSLog(@"Ping selected: %@", ((UILabel *)view).text);
                
                // obtain the station index
                NSError *error = nil;
                NSRegularExpression *regex =
                [NSRegularExpression
                 regularExpressionWithPattern:@"\\[\\d+\\]"
                 options:0 error:&error];
                NSRange range = NSMakeRange(0, ((UILabel *)view).text.length);
                NSTextCheckingResult *result =
                [regex firstMatchInString:((UILabel *)view).text
                                  options:0 range:range];
                if (result) {
                    NSRange matchRange = [result rangeAtIndex:0];
                    NSString *match =
                    [((UILabel *)view).text substringWithRange:matchRange];
                    range = NSMakeRange(1, match.length-1);
                    int index = [[match substringWithRange:range] intValue];
                    
                    // obtain associated Ping operation
                    PingOperation *ping = self.stations[index-1];
                    
                    // get date
                    pivc.date = ping.date; // switch to hops for trace
                }
            }
        }
    }
}

@end
