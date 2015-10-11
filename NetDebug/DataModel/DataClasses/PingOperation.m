//
//  PingOperation.m
//  NetDebug
//
//  Created by Petros Fountas on 08/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import "PingOperation.h"
#import "PingResponse.h"
#import "TraceOperation.h"


@implementation PingOperation

@dynamic target;
@dynamic packetSizeInBytes;
@dynamic numberOfPackets;
@dynamic numberOfHops;
@dynamic date;
@dynamic targetLocation;
@dynamic identifier;
@dynamic saved;
@dynamic standalone;
@dynamic responses;
@dynamic trace;

@end
