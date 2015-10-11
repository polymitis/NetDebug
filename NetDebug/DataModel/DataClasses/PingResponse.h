//
//  PingResponse.h
//  NetDebug
//
//  Created by Petros Fountas on 08/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class PingOperation;

@interface PingResponse : NSManagedObject

@property (nonatomic, retain) NSNumber * roundTripTime;
@property (nonatomic, retain) NSString * sourceAddress;
@property (nonatomic, retain) NSNumber * no;
@property (nonatomic, retain) PingOperation *ping;

@end
