//
//  DataModel.h
//  NetDebug
//
//  Created by Petros Fountas on 07/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "TraceOperation.h"
#import "PingOperation.h"
#import "PingResponse.h"





/** Data model operation type */
typedef NS_ENUM(NSUInteger, DataModelOperationType) {
    
    /** Unknown type of operation. */
    DataModelOperationTypeUnknown,
    
    /** DNS lookup */
    DataModelOperationTypeDNSLookup,
    
    /** Reverse DNS lookup */
    DataModelOperationTypeReverseDNSLookup,
    
    /** Ping operation */
    DataModelOperationTypePing,
    
    /** Trace operation */
    DataModelOperationTypeTrace,
};





/** Data model delegate protocol 
 
 @sa DataModel
 
 */
@protocol DataModelDelegateProtocol <NSObject>

@required

/** Informs the data model delegate about the successful completion of an operation.
 
 @param type     The type of the operation.
 @param context  The current CoreData model context.
 
 @sa DataModelOperationType
 */
- (void)dataModelOperation:(DataModelOperationType)type
     didSucceedWithContext:(NSManagedObjectContext *)context;


/** Informs the data model delegate about the error that caused an operation to fail.
 
 @param error The error.
 
 */
- (void)dataModelOperation:(DataModelOperationType)type
          didFailWithError:(NSError *)error;

@end





/** Data model
 
 The data model is responsible for managing all network and data operations. The data model uses CoreData for handling the data and the ping algorithm for performing the ping and trace operations.
 
 The following operations are supported:
 
 - Ping operation uses directly the ping algorithm to determine if a target location exists.
 
 - Trace operation exploits the TTL value of the IP packets, in order to trace all the intermediate network stations.
 
 - DNS lookup operation resolves a Fully Qualified Domain Name (FQDN) to an IP address.
 
 - Reverse DNS lookup resolves an IP address to a FQDN.
 
 */
@interface DataModel : NSObject


//------------------------------------------------------------------------------
/** @name Managing the data operations */
//------------------------------------------------------------------------------


/** The CoreData model context */
@property (strong, nonatomic, readonly) NSManagedObjectContext *context;


/** Save an operation.
 
 The operation must be a PingOperation or TraceOperation object.
 
 @param operation The operation.
 
 @return YES if the operation is saved, else NO.
 
 */
- (BOOL)saveOperation:(id)operation;


/** Delete an operation.
 
 The operation must be a PingOperation or TraceOperation object.
 
 @param operation The operation.
 
 @return YES if the operation is deleted, else NO.
 
 */
- (BOOL)deleteOperation:(id)operation;


//------------------------------------------------------------------------------
/** @name Managing the network operations */
//------------------------------------------------------------------------------


/** The IP address of the target network location. */
@property (strong, nonatomic, readonly) NSString *target;

/** The number of ICMP Echo packets used for probing the target. */
@property (strong, nonatomic, readonly) NSNumber *numberOfPackets;

/** The size of the ICMP Echo packets used for probing the target. */
@property (strong, nonatomic, readonly) NSNumber *packetSizeInBytes;

/** The resolved IP address of the target hostname */
@property (strong, nonatomic, readonly) NSString *ip;

/** The resolved hostname of the target IP address */
@property (strong, nonatomic, readonly) NSString *host;

/** The type of the current data model operation. */
@property (nonatomic, readonly) DataModelOperationType currentOperation;

/** The current ping response. */
@property (strong, nonatomic, readonly) PingResponse *currentPingResponse;

/** The current ping operation. */
@property (strong, nonatomic, readonly) PingOperation *currentPingOperation;

/** The current trace operation. */
@property (strong, nonatomic, readonly) TraceOperation *currentTraceOperation;

/** All trace operations. */
@property (strong, nonatomic) NSArray *traceOperations;

/** All ping operations. */
@property (strong, nonatomic) NSArray *pingOperations;


/** Perform DNS lookup of a specified FQDN.
 
 @param hostname The FQDN.
 @param delegate The delegate that will be informed about the status of the operation.
 
 @return YES if the operation is deleted, else NO.
 
 */
- (BOOL)performDNSLookupOf:(NSString *)hostname
                  delegate:(id<DataModelDelegateProtocol>)delegate;


/** Perform reverse DNS lookup of a specified IP address.
 
 @param ip The IP address.
 @param delegate The delegate that will be informed about the status of the operation.
 
 @return YES if the operation is initiated, else NO.
 
 @bug Sometimes it fails, but it doesn't affect the rest of the data model functionality.
 
 */
- (BOOL)performReverseDNSLookupOf:(NSString *)ip
                         delegate:(id<DataModelDelegateProtocol>)delegate;


/** Perform a ping operation.
 
 The ping operation uses directly the ping algorithm to determine if a target location exists.
 
 The ping operation performs the following steps:
 
    # Main tread
    1 Set self as ping algorithm delegate.
    2 Set ping algorithm timeout.
    3 Perform ping algorithm.
 
    # Ping operation initiated [Ping algorithm target action]
    1 Create a CoreData ping operation object.
 
    # ICMP packet received [Ping algorithm target action]
    1 Create a CoreData ping response object.
    2 Associate the ping response object with the ping operation object.
    3 Finish ping operation when the source address fo the IP packet of the ICMP Echo Reply packet is equal to the target.
 
 @param target      The target network location.
 @param npackets    The number of ICMP Echo packets used to probe the target.
 @param size        The size of ICMP Echo packets used to probe the target.
 @param delegate The delegate that will be informed about the status of the operation.
 
 @return YES if the operation is initiated, else NO.
 
 @sa PingAlgorithm
 
 */
- (BOOL)performPingOperationWith:(NSString *)target
                 numberOfPackets:(int)npackets
               packetSizeInBytes:(int)size
                        delegate:(id<DataModelDelegateProtocol>)delegate;


/** Perform a trace operation.
 
 The trace operation exploits the TTL value of the IP packets, in order to trace all the intermediate network stations.
 
 The trace operation performs the following steps:
 
    # Main thread
    1 Create a CoreData trace operation object.
    1 Set the initial TTL value to 1.
    2 Register a timer callback to perform the ping algorithm until TTL == 255.
 
    # Timer callback
    1 Set self as ping algorithm delegate.
    1 Clear ping algorithm timeout, because some stations might not respond.
    2 Perform ping algorithm.
    3 Increase TTL by 1.
 
    # Ping operation initiated [Ping algorithm target action]
    1 Create a CoreData ping operation object.
    2 Associate the ping operation object with the trace operation object.
     
    # ICMP packet received [Ping algorithm target action]
    1 Create a CoreData ping response object.
    2 Associate the ping response object with the ping operation object.
    3 Finish ping operation when the source address fo the IP packet of the ICMP Echo Reply packet is equal to the target.
 
 @param target      The target network location.
 @param npackets    The number of ICMP Echo packets used to probe the target.
 @param size        The size of ICMP Echo packets used to probe the target.
 @param delegate The delegate that will be informed about the status of the operation.
 
 @return YES if the operation is initiated, else NO.
 
 @sa PingAlgorithm
 
 */
- (BOOL)performTraceOperationWith:(NSString *)target
                  numberOfPackets:(int)npackets
                packetSizeInBytes:(int)size
                         delegate:(id<DataModelDelegateProtocol>)delegate;


/** Stops the current operation.
 
 */
- (void)stop;


//------------------------------------------------------------------------------
/** @name Utilities */
//------------------------------------------------------------------------------


/** Matches the input to a specified regular expression pattern
 
 @param input   The input string.
 @param pattern The regular expression pattern.
 
 @return YES is the input matches the specified pattern, else NO.
 
 */
- (BOOL)doesInput:(NSString *)input matchesPattern:(NSString *)pattern;


/** Returns the data model update notification.
 
 @return the data model update notification.
 
 */
+ (NSString *)dataModelUpdatedNotification;

@end
