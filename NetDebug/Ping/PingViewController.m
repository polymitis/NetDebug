//
//  PingViewController.m
//  NetDebug
//
//  Created by Petros Fountas on 27/11/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#import "AppDelegate.h"
#import "DataModel.h"
#import "PingInfoViewController.h"

#import "PingViewController.h"

@interface PingViewController ()
<UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate,
DataModelDelegateProtocol>

@property (strong, nonatomic) NSString *target;

@property (strong, nonatomic) DataModel *dataModel;

@property (strong, nonatomic) NSArray *responses;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView
*activityIndicator;

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

@property (strong, nonatomic) UIAlertView *pingFailedMessageAlert;

@property (strong, nonatomic) UIAlertView *illegalPacketSizeMessageAlert;

@property (strong, nonatomic) UIAlertView *illegalPacketNumberMessageAlert;

@property (strong, nonatomic) UIAlertView *hostnameUnknownMessageAlert;

@end

@implementation PingViewController

// adjusts the main view to the screen of the phone
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
    
    // keep original transforms
    self.networkTargetFieldOriginalTransform =
    self.networkTargetField.transform;
    self.packetSizeControlViewOriginalTransform =
    self.packetSizeControlView.transform;
    self.numberOfPacketsControlViewOriginalTransform =
    self.numberOfPacketsControlView.transform;
    
    // Ping operation failed alert
    self.pingFailedMessageAlert =
    [[UIAlertView alloc] initWithTitle:@"Ping failed"
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
    [super viewWillAppear:animated];
    [self resetPingControlView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (DataModel *)dataModel
{
    if (!_dataModel) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        _dataModel = appDelegate.dataModel;
    }
    return _dataModel;
}

// adjusts the selected textfield to the top of the keyboard
- (void)keyboardDidShow:(NSNotification *)notification
{
    
    [self resetPingControlView];
    
    // get keyboard frame
    CGRect keyboardFrame=
    [[[notification userInfo]
      objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // get screen height
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    // get adjusted keyboard Y
    CGFloat adjKeyboardY = screenHeight - keyboardFrame.size.height;
    
    
    // raise the view and use black font, in order for the user to see what is
    // being typed
    UIView *view;
    CGFloat dy = 0;
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
    self.previousValueOfTextField = sender.text; // keep current value
    sender.text = @""; // clear the textfield (expected behaviour)
    
    self.selectedTextField = sender;
    
}

// reset the view to its initial condition
- (void)resetPingControlView
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
    
    NSLog(@"Ping control view reseted!");
}

// closes the keyboard when the enter button is pressed
-(IBAction)textFieldReturn:(id)sender
{
    [sender resignFirstResponder];
    [self resetPingControlView];
}

// closes the keyboard when tap outside of it (expected behaviour)
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [[event allTouches] anyObject];
    
    // hide keyboard
    UIView *view = [touch view];
    if ([self.networkTargetField isFirstResponder]
        && view != self.networkTargetField) {
        [self.networkTargetField resignFirstResponder];
        [self resetPingControlView];
    } else if ([self.packetSizeField isFirstResponder]
               && view != self.packetSizeField) {
        [self.packetSizeField resignFirstResponder];
        [self resetPingControlView];
    } else if ([self.numberOfPacketsField isFirstResponder]
               && view != self.numberOfPacketsField) {
        [self.numberOfPacketsField resignFirstResponder];
        [self resetPingControlView];
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
         CGAffineTransformScale(self.saveAnimView.transform, 0.1, 0.1);
         self.saveAnimView.transform =
         CGAffineTransformTranslate(self.saveAnimView.transform, dx, dy);
         NSLog(@"Save animation finished");
     }               completion:
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
    
    [self.dataModel saveOperation:self.dataModel.currentPingOperation];
}

// called when the start button is pressed - initiates a ping operation
- (IBAction)startButtonPressed:(UIButton *)sender
{
    self.startButton.enabled = NO;
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    
    // try to start a ping operation
    if (![self.dataModel
         performPingOperationWith:self.target
         numberOfPackets:[self.numberOfPacketsField.text intValue]
         packetSizeInBytes:[self.packetSizeField.text intValue]
         delegate:self]) {

        [self resetPingControlView];
        [self.pingFailedMessageAlert show];
    }
}

#pragma mark - Stations Scroll View Data Source

// restricts the scrolling only to the Y axis
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
        if (view.tag == 1) { // 1st label on cell (Packet No)
            ((UILabel *)view).text =
            [NSString stringWithFormat:@"Packet %d",(int)indexPath.row+1];
        } else if (view.tag == 2) { // 2nd label on cell (Round-Trip-Time)
            ((UILabel *)view).text =
            [NSString stringWithFormat:@"%2.2f ms",
             [((PingResponse *)self.responses[indexPath.row]).
              roundTripTime doubleValue]*1e3];
        }
    }
    
    return cell;
}

#pragma mark - Data Model Operation Delegate

// @see in DataModel..
- (void)dataModelOperation:(DataModelOperationType)type
     didSucceedWithContext:(NSManagedObjectContext *)context
{
    if (type == DataModelOperationTypePing) {
        NSLog(@"Ping operation succeeded!");
        
        // update UI
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:@"no"
                                      ascending:YES
                                       selector:@selector(compare:)];
        NSArray *sortDescriptors =
        [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        
        self.responses =
        [[self.dataModel.currentPingOperation.responses
          sortedArrayUsingDescriptors:sortDescriptors] copy];
        
        self.commStatLabel.text = [NSString stringWithFormat:
                                   @"Send: %d packets, Received: %d packets",
                                   [self.dataModel.numberOfPackets intValue],
                                   (int)[self.responses count]];
        
        [self.packetsTableView reloadData];
        
        NSNumber *min_dt = [self.responses
                            valueForKeyPath:@"@min.roundTripTime"];
        NSNumber *max_dt = [self.responses
                            valueForKeyPath:@"@max.roundTripTime"];
        NSNumber *avg_dt = [self.responses
                            valueForKeyPath:@"@avg.roundTripTime"];
        
        if ([self.responses count]) {
            self.statusLabel.text =
            [NSString stringWithFormat:@"%@ reached!",
             self.dataModel.currentPingOperation.target];
            
            self.timeStatLabel.text =
            [NSString stringWithFormat:@"Min: %2.1f ms, Avg: %2.1f ms,"
             " Max: %2.1f ms",
             [min_dt doubleValue]*1e3,[avg_dt doubleValue]*1e3,
             [max_dt doubleValue]*1e3];
            
        } else { // no ICMP Echo Reply packets recieved
            self.statusLabel.text =
            [NSString stringWithFormat:@"%@",
             self.dataModel.currentPingOperation.target];
            
            self.timeStatLabel.text =
            [NSString stringWithFormat:@"Min: 0 ms, Avg: 0 ms, Max: 0 ms"];
        }
        
        [self resetPingControlView];
        self.saveButton.enabled = YES; // enable save
        self.validUnsavedOperation = YES; // keep save enabled if the view is
                                          // changed.
        
        NSLog(@"UI updated!");
    
    } else if (type == DataModelOperationTypeDNSLookup) {
        NSLog(@"DNS lookup operation succeeded!");
        
        self.target = self.dataModel.ip; // set the target - ready to ping
    }
}

// @see in DataModel..
- (void)dataModelOperation:(DataModelOperationType)type
          didFailWithError:(NSError *)error
{
    if (type == DataModelOperationTypePing) {
        NSLog(@"Ping operation failed!");
        
        // reset UI
        self.statusLabel.text =
        [NSString stringWithFormat:@"%@",
         self.target];
        
        self.commStatLabel.text = [NSString stringWithFormat:
                                   @"Send: %d packets, Received: %d packets",
                                   [self.dataModel.numberOfPackets intValue],0];
        self.responses = nil;
        
        self.timeStatLabel.text =
        [NSString stringWithFormat:@"Min: 0 ms, Avg: 0 ms, Max: 0 ms"];
        
        [self.packetsTableView reloadData];
        [self resetPingControlView];
        
        // inform the user
        [self.pingFailedMessageAlert show];
        
    } else if (type == DataModelOperationTypeDNSLookup) {
        NSLog(@"DNS lookup failed!");
        
        [self.hostnameUnknownMessageAlert show];
    }
}

@end
