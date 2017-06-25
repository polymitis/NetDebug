//
//  DataModel.m
//  NetDebug
//
//  Created by Petros Fountas on 07/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//
#include <netinet/in.h>
#include <arpa/inet.h>

#import "PingAlgorithm.h"

#import "DataModel.h"

#define MAX_HOPS 255 // IP.TTL is 8b

#define MAX_TRIES 5

@interface DataModel() <PingAlgorithmDelegateProtocol>

@property (strong, nonatomic) NSString *target;

@property (strong, nonatomic) NSNumber *numberOfPackets;

@property (strong, nonatomic) NSNumber *packetSizeInBytes;

@property (strong, nonatomic) NSString *ip;

@property (strong, nonatomic) NSString *host;

@property (strong, nonatomic) NSManagedObjectContext *context;

@property (nonatomic) DataModelOperationType currentOperation;

@property (strong, nonatomic) PingResponse *currentPingResponse;

@property (strong, nonatomic) PingOperation *currentPingOperation;

@property (strong, nonatomic) TraceOperation *currentTraceOperation;

@property (nonatomic) int currentHop;

@property (strong, nonatomic) NSTimer *traceTimer;

@property (strong, nonatomic) PingAlgorithm *pingAlgoritm;

@property (strong, nonatomic) id<DataModelDelegateProtocol> delegate;

@property (strong, nonatomic) UIManagedDocument *document;

@end

@implementation DataModel

- (PingAlgorithm *)pingAlgoritm
{
    if (!_pingAlgoritm) {
        _pingAlgoritm = [[PingAlgorithm alloc] init];
        _pingAlgoritm.delegate = self;
    }
    return _pingAlgoritm;
}

- (UIManagedDocument *)document
{
    if (!_document) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSURL *url = [[manager URLsForDirectory:NSDocumentDirectory
                                      inDomains:NSUserDomainMask] lastObject];
        url = [url URLByAppendingPathComponent:@"model.db"];
        
        _document = [[UIManagedDocument alloc] initWithFileURL:url];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
            // open document
            [_document openWithCompletionHandler:^(BOOL success) {
                if (success)
                    [self documentIsReady];
                else
                    NSLog(@"couldn’t open document at %@", url);
            }];
        } else { // file doesn't exist in path
            // create document
            [_document saveToURL:url forSaveOperation:UIDocumentSaveForCreating
               completionHandler:^(BOOL success) {
                   if (success)
                       [self documentIsReady];
                   else
                       NSLog(@"couldn’t create document at %@", url);
               }];
        }
    }
    
    return _document;
}

- (NSManagedObjectContext *)context
{
    if (!_context) _context = self.document.managedObjectContext;
    return _context;
}

- (void)documentIsReady
{
    if (self.document.documentState == UIDocumentStateNormal) {
        
        // notify everybody to reload the data model
        [[NSNotificationCenter defaultCenter]
         postNotificationName:[DataModel dataModelUpdatedNotification]
         object:self];
        
    }
}

- (BOOL)doesInput:(NSString *)input matchesPattern:(NSString *)pattern
{
    // prepare regex
    if (!input) return NO;
    
    NSError *error = nil;
    NSRegularExpression *regex =
    [NSRegularExpression
     regularExpressionWithPattern:pattern
     options:NSRegularExpressionCaseInsensitive
     error:&error];
    
    // find first match
    NSRange matchRange = [regex
                          rangeOfFirstMatchInString:input
                          options:NSMatchingReportProgress
                          range:(NSMakeRange(0, input.length))];
    
    if (matchRange.location == NSNotFound) return NO; // match not found
    return YES; // match found
}

- (NSArray *)pingOperations
{
    _pingOperations = nil;
    // fetch all saved ping operations not part of a trace operation
    NSFetchRequest *request =
    [NSFetchRequest fetchRequestWithEntityName:@"PingOperation"];
    request.predicate =
    [NSPredicate predicateWithFormat:@"saved == 1 && standalone == 1"];
    NSError *error;
    NSArray *results =
    [self.context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Fetch of Ping Operations failed with error: %@", error);
        
    } else if (![results count]) {
        NSLog(@"Ping operations not found");
        
    } else {
        NSLog(@"Ping operations found");
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:@"date"
                                      ascending:YES
                                       selector:@selector(compare:)];
        NSArray *sortDescriptors =
        [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        
        _pingOperations =
        [[results sortedArrayUsingDescriptors:sortDescriptors] copy];
    }
    return _pingOperations;
}

- (NSArray *)traceOperations
{
    _traceOperations = nil;
    // fetch all saved trace operations
    NSFetchRequest *request =
    [NSFetchRequest fetchRequestWithEntityName:@"TraceOperation"];
    request.predicate =
    [NSPredicate predicateWithFormat:@"saved == 1"];
    NSError *error;
    NSArray *results =
    [self.context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Fetch of Trace Operations failed with error: %@", error);
    } else if (![results count]) {
        NSLog(@"Trace operations not found");
    } else {
        NSLog(@"Trace operations found");
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:@"date"
                                      ascending:YES
                                       selector:@selector(compare:)];
        NSArray *sortDescriptors =
        [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        
        _traceOperations =
        [[results sortedArrayUsingDescriptors:sortDescriptors] copy];
    }
    return _traceOperations;
}

- (void)stop
{
    [self.pingAlgoritm stop];
    [self cleanupCurrentOperation];
}

- (BOOL)saveOperation:(id)operation
{
    if (![operation isMemberOfClass:[PingOperation class]]
        && ![operation isMemberOfClass:[TraceOperation class]]) {
        
        NSLog(@"Save operation failed with error: Undefined operation");
        
        return NO;
    }
    
    if ([operation isMemberOfClass:[PingOperation class]]) {
        NSLog(@"Ping operation detected");
        PingOperation *ping = (PingOperation *)operation;
        ping.saved = [NSNumber numberWithBool:YES];
        
    } else if ([operation isMemberOfClass:[TraceOperation class]]) {
        // if the trace is saved - all pings in it are considered saved
        NSLog(@"Trace operation detected");
        TraceOperation *trace = (TraceOperation *)operation;
        trace.saved = [NSNumber numberWithBool:YES];
    }
    
    NSLog(@"Operation marked to be saved");
    
    // notify everybody to reload the data model
    [[NSNotificationCenter defaultCenter]
     postNotificationName:[DataModel dataModelUpdatedNotification]
     object:self];
    
    NSLog(@"DataModelUpdated notification dispatched");
    
    return YES;
}

- (BOOL)deleteOperation:(id)operation
{
    if (![operation isMemberOfClass:[PingOperation class]]
        && ![operation isMemberOfClass:[TraceOperation class]]) {
        
        NSLog(@"Delete operation failed with error: Undefined operation");
        
        return NO;
    }
    
    [self.context deleteObject:operation];
    
    NSLog(@"Operation deleted");
    
    // notify everybody to reload the data model
    [[NSNotificationCenter defaultCenter]
     postNotificationName:[DataModel dataModelUpdatedNotification]
     object:self];
    
    NSLog(@"DataModelUpdated notification dispatched");
    
    
    return YES;
}

- (BOOL)performPingOperationWith:(NSString *)target
                 numberOfPackets:(int)npackets
               packetSizeInBytes:(int)size
                        delegate:(id<DataModelDelegateProtocol>)delegate
{
    // only IPv4 addresses allowed
    if (![self doesInput:target
          matchesPattern:
          @"^((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))$"])
        return NO;
    
    if (![self.currentPingOperation.saved boolValue] && ![self.currentTraceOperation.saved boolValue]) {
        [self cleanupCurrentPingOperation]; // cleanup from previous operation
    }
    
    // perform ping operation
    self.delegate = delegate;
    self.pingAlgoritm.timeout = 30*log10(10*(npackets/3));
    self.currentOperation = DataModelOperationTypePing;
    [self.pingAlgoritm performWithTarget:target
                         numberOfPackets:npackets
                         maxNumberOfHops:MAX_HOPS
                       packetSizeInBytes:size
                        maxNumberOfTries:MAX_TRIES];
    
    return YES;
}

- (void)traceTimerOperation:(NSTimer*)theTimer
{
    // perform ping
    self.pingAlgoritm.timeout = -1; // Some station might not respond
    [self.pingAlgoritm performWithTarget:self.target
                         numberOfPackets:[self.numberOfPackets intValue]
                         maxNumberOfHops:self.currentHop++
                       packetSizeInBytes:[self.packetSizeInBytes intValue]
                        maxNumberOfTries:MAX_TRIES];
    
    // check maximum TTL condition
    if (self.currentHop > MAX_HOPS) {
        NSLog(@"Maximum number of hops reached");
        [self.traceTimer invalidate];
        self.traceTimer = nil;
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Destination is unreachable"
                       forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"TraceOperation"
                                             code:-1
                                         userInfo:errorDetail];
        [self.delegate dataModelOperation:self.currentOperation
                         didFailWithError:error];
    }
}

- (BOOL)performTraceOperationWith:(NSString *)target
                  numberOfPackets:(int)npackets
                packetSizeInBytes:(int)size
                         delegate:(id<DataModelDelegateProtocol>)delegate
{
    // only IPv4 addresses allowed
    if (![self doesInput:target
          matchesPattern:
          @"^((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))\\."
          "((2[0-5][0-5])|(2[0-4][0-9])|(1[0-9][0-9])|([0-9]?[0-9]))$"])
        return NO;
    
    // cleanup previous operation
    if (![self.currentTraceOperation.saved boolValue]) {
        [self cleanupCurrentTraceOperation]; // cleanup from previous operation
    }
    
    // create & save trace operation
    TraceOperation *operation =
    [NSEntityDescription insertNewObjectForEntityForName:@"TraceOperation"
                                  inManagedObjectContext:self.context];
    operation.target = target;
    operation.numberOfPackets = [NSNumber numberWithInt:npackets];
    operation.packetSizeInBytes = [NSNumber numberWithInt:size];
    operation.date = [NSDate date];
    self.currentTraceOperation = operation;
    
    // perform Trace operation
    self.currentHop = 1; // TTL = 1
    self.target = target;
    self.currentOperation = DataModelOperationTypeTrace;
    self.numberOfPackets = [NSNumber numberWithInt:npackets];
    self.packetSizeInBytes = [NSNumber numberWithInt:size];
    self.delegate = delegate;
    self.traceTimer = [NSTimer
                       scheduledTimerWithTimeInterval:0.5
                       target:self
                       selector:@selector(traceTimerOperation:)
                       userInfo:nil
                       repeats:YES];
    
    return YES;
}

void dnsLookupCallback(CFHostRef theHost,
                 CFHostInfoType typeInfo,
                 const CFStreamError *error,
                 void *info)
{
    // get object associated with socket
    DataModel *dataModel  = (__bridge DataModel*) info;
    Boolean result;
    CFArrayRef addresses = CFHostGetAddressing(theHost, &result);
    if (result == TRUE && addresses != NULL) {
        NSLog(@"DNS lookup succeded");
        struct sockaddr_in* address;
        CFDataRef addrRef = (CFDataRef)CFArrayGetValueAtIndex(addresses, 0);
        address = (struct sockaddr_in*)CFDataGetBytePtr(addrRef);
        if(address != NULL){
            // get ip address
            dataModel.ip =
            [NSString stringWithCString:inet_ntoa(address->sin_addr)
                               encoding:NSASCIIStringEncoding];
            
            NSLog(@"Host resolved to %@", dataModel.ip);
            
            [dataModel.delegate dataModelOperation:dataModel.currentOperation
                             didSucceedWithContext:dataModel.context];
        } else {
            NSLog(@"DNS lookup failed, address not found");
            [dataModel.delegate dataModelOperation:dataModel.currentOperation
                                  didFailWithError:nil];
        }
    } else {
        NSLog(@"DNS lookup failed");
        [dataModel.delegate dataModelOperation:dataModel.currentOperation
                              didFailWithError:nil];
    }
}

- (BOOL)performDNSLookupOf:(NSString *)hostname
                  delegate:(id<DataModelDelegateProtocol>)delegate
{
    self.delegate = delegate;
    self.currentOperation = DataModelOperationTypeDNSLookup;
    
    CFHostClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFHostRef host =
    CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname);
    CFHostSetClient(host, dnsLookupCallback, &context);
    CFHostScheduleWithRunLoop(host, CFRunLoopGetCurrent(),
                              kCFRunLoopDefaultMode);
    return CFHostStartInfoResolution (host, kCFHostAddresses, NULL);
}

// @see https://developer.apple.com/library/mac/samplecode/SimplePing/Listings/SimplePing_m.html
- (NSError *)toStreamError:(CFStreamError)streamError
{
    NSDictionary *  userInfo;
    NSError *       error;
    
    if (streamError.domain == kCFStreamErrorDomainNetDB) {
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithInteger:streamError.error],
                    kCFGetAddrInfoFailureKey,nil];
    } else {
        userInfo = nil;
    }
    
    error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork
                                code:kCFHostErrorUnknown userInfo:userInfo];
    assert(error != nil);
    
    return error;
}

void reverseDNSLookupCallback(CFHostRef theHost,
                        CFHostInfoType typeInfo,
                        const CFStreamError *error,
                        void *info)
{
    // get object associated with socket
    DataModel *dataModel  = (__bridge DataModel *) info;
    
    if (error) {
        NSError *err = [dataModel toStreamError:*error];
        NSLog(@"DNS lookup failed with error:%@",err);
    }
    
    Boolean result;
    CFArrayRef hosts = CFHostGetNames(theHost, &result);
    if (result == TRUE && hosts != NULL) {
        NSLog(@"DNS lookup succeded");
        char *host;
        CFDataRef hostRef = (CFDataRef)CFArrayGetValueAtIndex(hosts, 0);
        host = (char *)CFDataGetBytePtr(hostRef);
        if (host != NULL) {
            // get hostname
            dataModel.host =
            [NSString stringWithCString:host
                               encoding:NSASCIIStringEncoding];
            
            NSLog(@"IP resolved to %@", dataModel.host);
            
            [dataModel.delegate dataModelOperation:dataModel.currentOperation
                             didSucceedWithContext:dataModel.context];
        } else {
            NSLog(@"DNS lookup failed, host not found");
            [dataModel.delegate dataModelOperation:dataModel.currentOperation
                                  didFailWithError:nil];
        }
    } else {
        NSLog(@"DNS lookup failed");
        [dataModel.delegate dataModelOperation:dataModel.currentOperation
                              didFailWithError:nil];
    }
}

- (BOOL)performReverseDNSLookupOf:(NSString *)ip
                         delegate:(id<DataModelDelegateProtocol>)delegate
{
    self.delegate = delegate;
    self.currentOperation = DataModelOperationTypeReverseDNSLookup;
    
    CFHostClientContext context =
    {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    // get the address
    struct sockaddr_in addr;
    const char *caddr = [ip cStringUsingEncoding:NSASCIIStringEncoding];
    if (inet_pton(AF_INET, caddr, &addr.sin_addr) < 0) {
        NSLog(@"Reverse DNS Lookup failed");
        [self.delegate dataModelOperation:self.currentOperation
                         didFailWithError: [NSError
                                            errorWithDomain:NSPOSIXErrorDomain
                                            code:errno
                                            userInfo:nil]];
        return NO;
    }

    CFDataRef address =
    CFDataCreate(NULL, (UInt8 *)&addr, sizeof(addr));
    CFHostRef host =
    CFHostCreateWithAddress(kCFAllocatorDefault, address);
    CFRelease(address);
    CFHostSetClient(host, reverseDNSLookupCallback, &context);
    CFHostScheduleWithRunLoop(host, CFRunLoopGetCurrent(),
                              kCFRunLoopDefaultMode);
    return CFHostStartInfoResolution (host, kCFHostNames, NULL);
}

+ (NSString *)dataModelUpdatedNotification
{
    return @"DataModelUpdatedNotification";
}

#pragma mark - Ping Algorithm Delegate

- (void)pingPerformedWithTarget:(NSString *)target
                     identifier:(int)identifier
                numberOfPackets:(int)npackets
                maxNumberOfHops:(int)hops
              packetSizeInBytes:(int)size
{
    NSLog(@"%d ICMP packets with identifier %d with ttl = %d "
          "were successfully send to %@",
          npackets,identifier,hops,target);
    
    self.target = target;
    self.numberOfPackets = [NSNumber numberWithInt:npackets];
    self.packetSizeInBytes = [NSNumber numberWithInt:size];
    
    // create & save ping operation
    PingOperation *operation =
    [NSEntityDescription insertNewObjectForEntityForName:@"PingOperation"
                                  inManagedObjectContext:self.context];
    operation.target = target;
    operation.identifier = [NSNumber numberWithInt:identifier];
    operation.numberOfPackets = [NSNumber numberWithInt:npackets];
    operation.numberOfHops = [NSNumber numberWithInt:hops];
    operation.packetSizeInBytes = [NSNumber numberWithInt:size];
    operation.date = [NSDate date];
    operation.standalone =
    [NSNumber numberWithBool:(self.currentOperation == DataModelOperationTypePing)? YES : NO];
    operation.trace = (self.currentOperation == DataModelOperationTypeTrace)? self.currentTraceOperation : nil;
    
    self.currentPingOperation = operation;
    
    NSLog(@"Ping operation { target: %@, identifier: %@, numberOfPackets: %@,"
          " numberOfHops: %@, packetSizeInBytes: %@, date: %@ } saved",
          operation.target, operation.identifier, operation.numberOfPackets,
          operation.numberOfHops, operation.packetSizeInBytes, operation.date);
}

- (void)icmpPacketReceivedWithData:(NSData *)packet
                        identifier:(int)identifier
                    sequenceNumber:(int)seqnum
                     roundTripTime:(NSTimeInterval)dt
                              type:(PingAlgorithmICMPType)type
                              from:(NSString *)src
{
    
    NSLog(@"[%d:%d] ICMP packet recieved in %f from %@",
          identifier,seqnum,dt,src);
    
    // create & save ping response
    PingResponse *response =
    [NSEntityDescription insertNewObjectForEntityForName:@"PingResponse"
                                  inManagedObjectContext:self.context];
    // number of response (No) - necessary for ordering
    if (!self.currentPingResponse.no) {
        response.no = [NSNumber numberWithInteger:0];
    } else {
        int previousValue = [self.currentPingResponse.no intValue];
        response.no = [NSNumber numberWithInteger:previousValue+1];
    }
    response.sourceAddress = src;
    response.roundTripTime = [NSNumber numberWithDouble:dt];
    
    // get associated ping operation
    NSFetchRequest *request = [NSFetchRequest
                               fetchRequestWithEntityName:@"PingOperation"];
    request.predicate = [NSPredicate
                         predicateWithFormat:@"identifier = %d", identifier];
    NSError *error;
    NSArray *fetchedObjects = [self.context executeFetchRequest:request
                                                          error:&error];
    if (!fetchedObjects) {
        NSLog(@"Failed to fetch Ping operation with identifier %d",
              identifier);
        
        [self cleanupCurrentOperation];
        
        [self.delegate dataModelOperation:self.currentOperation
                         didFailWithError:error];
    } else if ([fetchedObjects count]) { // Ping operation found
        
        // associate ping operation with response
        response.ping = (PingOperation *)fetchedObjects[0];
        
        self.currentPingResponse = response;
        
        // check if target has been reached (trace Operation)
        if ([self.target isEqual:@"255.255.255.255"]
            || [self.target isEqual:src]) {
            [self.traceTimer invalidate];
            self.traceTimer = nil;
            [self.delegate dataModelOperation:self.currentOperation
                        didSucceedWithContext:self.context];
        }
    }
}

- (void)pingDidFailWithError:(NSError *)error
{
    NSLog(@"Ping failed with error %s",strerror((int)error.code));
    
    [self cleanupCurrentOperation];
    
    [self.delegate dataModelOperation:self.currentOperation
                     didFailWithError:error];
}

- (void)cleanupCurrentOperation
{
    [self cleanupCurrentPingOperation];
    [self cleanupCurrentTraceOperation];
}

- (void)cleanupCurrentPingOperation
{
    NSLog(@"Cleaning up current Ping operation");
    if (self.currentPingOperation
        && (![self.currentPingOperation.responses count]
            || ![self.currentPingOperation.saved boolValue])) {
            [self.context deleteObject:self.currentPingOperation];
            self.currentPingOperation = nil;
        }
}

- (void)cleanupCurrentTraceOperation
{
    NSLog(@"Cleaning up current Trace operation");
    if (self.currentTraceOperation
        && (![self.currentTraceOperation.pings count]
            || ![self.currentTraceOperation.saved boolValue])) {
            [self.context deleteObject:self.currentTraceOperation];
            self.currentTraceOperation = nil;
        }
    if (self.traceTimer) {
        [self.traceTimer invalidate];
        self.traceTimer = nil;
    }
}

@end
