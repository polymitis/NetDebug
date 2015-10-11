//
//  TraceViewController.m
//  NetDebug
//
//  Created by Petros Fountas on 27/11/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#import "AppDelegate.h"
#import "DataModel.h"
#import "PingInfoViewController.h"

#import "TraceViewController.h"

@interface TraceViewController ()
<UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate,
DataModelDelegateProtocol>

@property (strong, nonatomic) NSString *target;

@property (strong, nonatomic) DataModel *dataModel;

@property (strong, nonatomic) NSArray *stations;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView
*activityIndicator;

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

@property (nonatomic, getter=isOperationValidAndUnsaved)
BOOL validUnsavedOperation;

@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (strong, nonatomic) NSString *previousValueOfTextField;

@property (strong, nonatomic) UITextField *selectedTextField;

@property (weak, nonatomic) IBOutlet UITextField *networkTargetField;
@property (nonatomic) CGAffineTransform
networkTargetFieldOriginalTransform;

@property (weak, nonatomic) IBOutlet UIView *packetSizeControlView;
@property (weak, nonatomic) IBOutlet UITextField *packetSizeField;
@property (nonatomic) CGAffineTransform
packetSizeControlViewOriginalTransform;

@property (weak, nonatomic) IBOutlet UIView *numberOfPacketsControlView;
@property (weak, nonatomic) IBOutlet UITextField *numberOfPacketsField;
@property (nonatomic) CGAffineTransform
numberOfPacketsControlViewOriginalTransform;

@property (weak, nonatomic) IBOutlet UIImageView *saveAnimView;

@property (strong, nonatomic) UIAlertView *traceFailedMessageAlert;

@property (strong, nonatomic) UIAlertView *illegalPacketSizeMessageAlert;

@property (strong, nonatomic) UIAlertView *illegalPacketNumberMessageAlert;

@property (strong, nonatomic) UIAlertView *hostnameUnknownMessageAlert;

@end

@implementation TraceViewController

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
    
    // keep original transforms
    self.networkTargetFieldOriginalTransform =
    self.networkTargetField.transform;
    self.packetSizeControlViewOriginalTransform =
    self.packetSizeControlView.transform;
    self.numberOfPacketsControlViewOriginalTransform =
    self.numberOfPacketsControlView.transform;
    
    // Trace operation failed alert
    self.traceFailedMessageAlert =
    [[UIAlertView alloc] initWithTitle:@"Trace failed"
                               message:@"Try again. There is the case "
                                        "that some targets will not respond "
                                        "for security reasons, otherwise the "
                                        "target might not exist, or the size "
                                        "or number of packets specified cannot"
                                        "be handled by the network or the "
                                        "target."
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil];
    
    // Illegal packet size alert
    self.illegalPacketSizeMessageAlert =
    [[UIAlertView alloc] initWithTitle:@"Size not supported"
                               message:@"Only values of power of 2 and "
                                        "between 8 and 64760 are supported."
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil];
    
    // Illegal packet number alert
    self.illegalPacketNumberMessageAlert =
    [[UIAlertView alloc] initWithTitle:@"Number not supported"
                               message:@"Only values between 1 and 255 are "
                                        "supported."
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil];
    
    // Hostname resolution failed alert
    self.hostnameUnknownMessageAlert =
    [[UIAlertView alloc] initWithTitle:@"Hostname unknown"
                               message:@"Try again, or check the spelling "
                                        "of your target."
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardDidShow:)
     name:UIKeyboardDidShowNotification
     object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self resetTraceControlView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (DataModel *)dataModel
{
    if (!_dataModel) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        _dataModel = appDelegate.dataModel;
    }
    return _dataModel;
}

// adjusts the selected textfield to the top of the keyboard
- (void)keyboardDidShow:(NSNotification *)notification
{
    
    [self resetTraceControlView];
    
    // get keyboard frame
    CGRect keyboardFrame=
    [[[notification userInfo]
      objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // get screen height
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    // get adjusted keyboard Y
    CGFloat adjKeyboardY = screenHeight - keyboardFrame.size.height;
    
    
    // raise the view for the user to see what is being typed
    CGFloat dy = 0;
    UIView *view = nil;
    if ([self.networkTargetField isEqual:self.selectedTextField]) {
        view = self.networkTargetField;
        self.networkTargetField.textColor = [UIColor blackColor];
        CGFloat adjSelectedViewY =
        [view convertRect:view.frame toView:nil].origin.y;
        dy = adjKeyboardY - adjSelectedViewY - 35;
    }
    else if ([self.packetSizeField isEqual:self.selectedTextField]) {
        view = self.packetSizeControlView;
        self.packetSizeField.textColor = [UIColor blackColor];
        view.backgroundColor = self.view.backgroundColor;
        CGFloat adjSelectedViewY =
        [view convertRect:view.frame toView:nil].origin.y;
        dy = adjKeyboardY - adjSelectedViewY + 3;
    }
    else if ([self.numberOfPacketsField isEqual:self.selectedTextField]) {
        view = self.numberOfPacketsControlView;
        self.numberOfPacketsField.textColor = [UIColor blackColor];
        view.backgroundColor = self.view.backgroundColor;
        CGFloat adjSelectedViewY =
        [view convertRect:view.frame toView:nil].origin.y;
        dy = adjKeyboardY - adjSelectedViewY + 41;
    }
    
    // perform animation
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:
     ^{
         NSLog(@"TextField view rise animation started");
         view.transform = CGAffineTransformTranslate(view.transform, 0, dy);
         NSLog(@"TextField view rise by %f points",dy);
     }               completion:
     nil];
}

// @see https://developer.apple.com/library/ios/qa/qa1817/_index.html
- (UIImage *)snapshot:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSLog(@"Snapshot aquired");
    
    return image;
}

#pragma mark - Controls

// called when a text field is selected
- (IBAction)editTextField:(UITextField *)sender {
    
    // clear textfield
    self.previousValueOfTextField = sender.text;
    sender.text = @"";
    
    self.selectedTextField = sender;
}

// reset the view to its initial condition
- (void)resetTraceControlView
{
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    
    // reset position and background color of all movable subviews
    self.networkTargetField.textColor = [UIColor lightGrayColor];
    self.networkTargetField.transform =
    self.networkTargetFieldOriginalTransform;
    self.networkTargetField.backgroundColor = [UIColor whiteColor];
    
    self.packetSizeField.textColor = [UIColor lightGrayColor];
    self.packetSizeControlView.transform =
    self.packetSizeControlViewOriginalTransform;
    self.packetSizeControlView.backgroundColor = [UIColor clearColor];
    
    self.numberOfPacketsField.textColor = [UIColor lightGrayColor];
    self.numberOfPacketsControlView.transform =
    self.numberOfPacketsControlViewOriginalTransform;
    self.numberOfPacketsControlView.backgroundColor = [UIColor clearColor];
    
    self.startButton.enabled = YES;
    if (self.validUnsavedOperation)
        self.saveButton.enabled = YES;
    else
        self.saveButton.enabled = NO;
    
    NSLog(@"Trace control view reseted!");
}

// closes the keyboard when the enter button is pressed
-(IBAction)textFieldReturn:(id)sender
{
    [sender resignFirstResponder];
    [self resetTraceControlView];
}

// closes the keyboard when tap outside of it (expected behaviour)
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [[event allTouches] anyObject];
    
    // hide keyboard
    UIView *view = [touch view];
    if ([self.networkTargetField isFirstResponder]
        && view != self.networkTargetField) {
        [self.networkTargetField resignFirstResponder];
        [self resetTraceControlView];
    } else if ([self.packetSizeField isFirstResponder]
               && view != self.packetSizeField) {
        [self.packetSizeField resignFirstResponder];
        [self resetTraceControlView];
    } else if ([self.numberOfPacketsField isFirstResponder]
               && view != self.numberOfPacketsField) {
        [self.numberOfPacketsField resignFirstResponder];
        [self resetTraceControlView];
    }
    
    [super touchesBegan:touches withEvent:event];
}

// checks for illegal or unresolved target values
- (IBAction)networkTargetChanged:(UITextField *)sender
{
    self.target = nil;
    if ([sender.text isEqualToString:@""]) {
        sender.text = self.previousValueOfTextField;
    }
    // input must conform to IPv4 address representation
    if (![self.dataModel doesInput:sender.text
                    matchesPattern:
          @"^((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))$"]) {
        
        if (![self.dataModel performDNSLookupOf:sender.text delegate:self]) {
            sender.text = self.previousValueOfTextField;
            [self.hostnameUnknownMessageAlert show];
        }
    } else {
        self.target = sender.text;
    }
}

// checks for illegal packet sizes
- (IBAction)packetSizeChanged:(UITextField *)sender
{
    // input must be between [8 - 65515]
    int n = [sender.text intValue];
    if ((n < 8 || 64760 < n) || remainder(n,2)) {
        sender.text = self.previousValueOfTextField;
        [self.illegalPacketSizeMessageAlert show];
    }
}

// checks for illegal number of packets
- (IBAction)numberOfPacketsChanged:(UITextField *)sender
{
    // input must be between [1 - 255]
    int n = [sender.text intValue];
    if (n < 1 || 255 < n) {
        sender.text = self.previousValueOfTextField;
        [self.illegalPacketNumberMessageAlert show];
    }
}

// animates the save operation.
- (void)animateSaveOperation
{
    
    UIImage *image = [self snapshot:self.view];
    NSLog(@"UIImage obj: %@",image);
    self.saveAnimView.image = image;
    [self.saveAnimView sizeToFit];
    NSLog(@"View image is in place");
    
    CGFloat dx = 0;
    CGFloat dy = 0;
    
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    NSLog(@"Screen height: %.1f", screenHeight);
    
    // the following adjustment values were determined by experimentation
    if (screenHeight == 480) {
        NSLog(@"iPhone 4/4s detected");
        dx = 1100;
        dy = 2000;
        
    } else if (screenHeight == 568) {
        NSLog(@"iPhone 5/5s detected");
        dx = 1100;
        dy = 2500;
        
    } else if (screenHeight == 667) {
        NSLog(@"iPhone 6 detected");
        dx = 1250;
        dy = 3000;
    }
    
    // perform animation
    self.saveAnimView.hidden = NO;
    CGAffineTransform original = self.saveAnimView.transform;
    [UIView animateWithDuration:0.5
                          delay:0.2
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:
     ^{
         NSLog(@"Save animation started");
         self.saveAnimView.transform =
         CGAffineTransformScale(self.saveAnimView.transform,
                                0.1, 0.1);
         self.saveAnimView.transform =
         CGAffineTransformTranslate(self.saveAnimView.transform,
                                    dx, dy);
         NSLog(@"Save animation finished");
     }
                     completion:
     ^(BOOL finished){
         self.saveAnimView.transform = original;
         self.saveAnimView.hidden = YES;
         self.saveAnimView.image = nil;
         
     }];
    
}

// called when the save button is pressed
- (IBAction)saveButtonPressed:(UIButton *)sender
{
    self.saveButton.enabled = NO;
    self.validUnsavedOperation = NO;
    
    [self animateSaveOperation];
    
    [self.dataModel saveOperation:self.dataModel.currentTraceOperation];
}

// called when the start button is pressed - initiates a trace operation
- (IBAction)startButtonPressed:(UIButton *)sender
{
    self.startButton.enabled = NO;
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    
    // try to start a trace operation
    if (![self.dataModel
         performTraceOperationWith:self.target
         numberOfPackets:[self.numberOfPacketsField.text intValue]
         packetSizeInBytes:[self.packetSizeField.text intValue]
         delegate:self]) {
        
        [self resetTraceControlView];
        [self.traceFailedMessageAlert show];
    }
}

#pragma mark - Stations Scroll View Data Source

// restricts the scrolling only to the Y axis
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

// @see in DataModel..
- (void)dataModelOperation:(DataModelOperationType)type
     didSucceedWithContext:(NSManagedObjectContext *)context
{
    if (type == DataModelOperationTypeTrace) {
        NSLog(@"Trace operation succeeded!");
        
        // update UI
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:@"numberOfHops"
                                      ascending:YES
                                       selector:@selector(compare:)];
        NSArray *sortDescriptors =
        [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        
        self.stations =
        [[self.dataModel.currentTraceOperation.pings
          sortedArrayUsingDescriptors:sortDescriptors] copy];
        
        [self.stationsTableView reloadData];
        
        if ([self.stations count]) {
            self.statusLabel.text =
            [NSString
             stringWithFormat:@"%@ in [%lu]",
             self.dataModel.currentTraceOperation.target,
             (unsigned long)[self.stations count]];
        } else { // no ICMP Echo Reply packets recieved (its ok for trace)
            self.statusLabel.text =
            [NSString stringWithFormat:@"%@",
             self.dataModel.currentTraceOperation.target];
        }
        
        [self resetTraceControlView];
        self.saveButton.enabled = YES; // enable save
        self.validUnsavedOperation = YES; // keep save enabled if the view is
                                          // changed.
        
        NSLog(@"UI updated!");
        
    } else if (type == DataModelOperationTypeDNSLookup) {
        NSLog(@"DNS lookup operation succeeded!");
        
        self.target = self.dataModel.ip; // set the target - ready to trace
    }
}

- (void)dataModelOperation:(DataModelOperationType)type
          didFailWithError:(NSError *)error
{
    if (type == DataModelOperationTypeTrace) {
        NSLog(@"Trace operation failed!");
        
        // reset UI
        self.statusLabel.text =
        [NSString stringWithFormat:@"%@",
         self.target];
        
        self.stations = nil;
        
        [self.stationsTableView reloadData];
        [self resetTraceControlView];
        [self.traceFailedMessageAlert show];
        
    }  else if (type == DataModelOperationTypeDNSLookup) {
        NSLog(@"DNS lookup failed!");
        
        [self.hostnameUnknownMessageAlert show];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIViewController *dvc = [segue destinationViewController];
    
    if ([dvc isMemberOfClass:[PingInfoViewController class]]
        && [sender isMemberOfClass:[UIButton class]]) {
        
        PingInfoViewController *pivc = (PingInfoViewController *)dvc;
        
        // extract the network station date from the sender cell view
        //
        //      view -> label -> REGEX -> ping -> date
        //
        pivc.date = nil;
        UIButton *infoButton = sender;
        UIView *cellContextView = infoButton.superview;
        for (UIView *view in cellContextView.subviews) {
            if (view.tag == 1) { // get the subview
                
                NSLog(@"Ping selected: %@", ((UILabel *)view).text);
                
                // obtain the station index with regex
                NSError *error = nil;
                NSRegularExpression *regex =
                [NSRegularExpression
                 regularExpressionWithPattern:@"\\[\\d+\\]"
                 options:0 error:&error];
                NSRange range = NSMakeRange(0, ((UILabel *)view).text.length);
                NSTextCheckingResult *result =
                [regex firstMatchInString:((UILabel *)view).text
                                  options:0 range:range];
                
                if (result) { // if the index is found
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
