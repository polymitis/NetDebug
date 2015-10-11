//
//  TraceOperation.h
//  NetDebug
//
//  Created by Petros Fountas on 08/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class PingOperation;

@interface TraceOperation : NSManagedObject

@property (nonatomic, retain) NSNumber * packetSizeInBytes;
@property (nonatomic, retain) NSNumber * numberOfPackets;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * target;
@property (nonatomic, retain) NSNumber * saved;
@property (nonatomic, retain) NSSet *pings;
@end

@interface TraceOperation (CoreDataGeneratedAccessors)

- (void)addPingsObject:(PingOperation *)value;
- (void)removePingsObject:(PingOperation *)value;
- (void)addPings:(NSSet *)values;
- (void)removePings:(NSSet *)values;

@end
