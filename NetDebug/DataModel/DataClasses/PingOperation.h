//
//  PingOperation.h
//  NetDebug
//
//  Created by Petros Fountas on 08/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class PingResponse, TraceOperation;

@interface PingOperation : NSManagedObject

@property (nonatomic, retain) NSString * target;
@property (nonatomic, retain) NSNumber * packetSizeInBytes;
@property (nonatomic, retain) NSNumber * numberOfPackets;
@property (nonatomic, retain) NSNumber * numberOfHops;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) id targetLocation;
@property (nonatomic, retain) NSNumber * identifier;
@property (nonatomic, retain) NSNumber * saved;
@property (nonatomic, retain) NSNumber * standalone;
@property (nonatomic, retain) NSSet *responses;
@property (nonatomic, retain) TraceOperation *trace;
@end

@interface PingOperation (CoreDataGeneratedAccessors)

- (void)addResponsesObject:(PingResponse *)value;
- (void)removeResponsesObject:(PingResponse *)value;
- (void)addResponses:(NSSet *)values;
- (void)removeResponses:(NSSet *)values;

@end
