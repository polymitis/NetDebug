//
//  PingAlgorithm.h
//  Trace
//
//  Created by Petros Fountas on 03/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import <Foundation/Foundation.h>





/** Ping algorithm ICMP Types */
typedef NS_ENUM(NSUInteger, PingAlgorithmICMPType) {
    
    /** Unknown ICMP packet. */
    PingAlgorithmICMPTypeUnknown,
    
    /** ICMP Echo Reply packet. */
    PingAlgorithmICMPTypeEchoReply,
    
    /** ICMP Destination Unreachable packet. */
    PingAlgorithmICMPTypeDestUnreach,
    
    /** ICMP Time Exceeded packet. */
    PingAlgorithmICMPTypeTimeExceeded,
};





/** Ping algorithm delegate protocol
 
 @sa PingAlgorithm
 
 */
@protocol PingAlgorithmDelegateProtocol

@required

/** Informs about the successful transmission of ICMP Echo packages.
 
 This method informs the Ping algorithm delegate that the method performWithTarget:numberOfPackets:maxNumberOfHops:packetSizeInBytes:maxNumberOfTries: has successfully transmitted the ICMP Echo packets.
 
 @param target      The IP address of the target network location.
 @param identifier  The ping operation identifier.
 @param npackets    The number of ICMP Echo packets to be send.
 @param hops        The maximum number of times, a packet can be forwarded by an intermediate network location (value of the IP TTL field).
 @param size        The size of ICMP Echo packet.
 
 */
- (void)pingPerformedWithTarget:(NSString *)target
                     identifier:(int)identifier
                numberOfPackets:(int)npackets
                maxNumberOfHops:(int)hops
              packetSizeInBytes:(int)size;

/** Informs about the reception of an ICMP packet.
 
 This method informs the ping algorithm delegate that an ICMP reply packet has been received in response to the packets transmitted using the method performWithTarget:numberOfPackets:maxNumberOfHops:packetSizeInBytes:maxNumberOfTries: .
 
 @param packet      The IP address of the target network location.
 @param identifier  The ping operation identifier.
 @param seqnum      The packet sequence number.
 @param dt          The packet round-trip time.
 @param type        The type of packet.
 @param src         The IP address of packet source (it can be equal to target).
 
 @sa PingAlgorithmICMPType
 
 */
- (void)icmpPacketReceivedWithData:(NSData *)packet
                        identifier:(int)identifier
                    sequenceNumber:(int)seqnum
                     roundTripTime:(NSTimeInterval)dt
                              type:(PingAlgorithmICMPType)type
                              from:(NSString *)src;

/** Informs about the error, that caused the Ping operation to fail.
 
 This method informs the ping algorithm delegate that the ping algorithm operation has failed.
 
 @param error The error.
 
 */
- (void)pingDidFailWithError:(NSError *)error;

@end





/** Ping algorithm 
 
 The ping algorithm performs a network debugging procedure, which is used to identify if a target network location exixts or it is operational. This procedure is based on the use of the ICMP Echo protocol, which is implemented by all network devices supporting the TCP/IP network stack. When a network device receives an ICMP echo packet, it is required to reply by transmitting back an ICMP Echo Reply packet. Many network devices choose to drop the ICMP Echo requests, due to security reasons and most of the times the network generates and transmits back an ICMP Destination Unreachable packet. The ICMP packets are encapsulated in IP packets. Every IP packet has a field in its header, called TTL, which is decreased by one every time the packet is handled by an intermediate network device, like a router. If the value of the field reaches zero before reaching its destination, the intermediate network device will generate and transmit back an ICMP Time Exceeded packet. By exploiting this behavior, the algorithm can be also used to trace all the intermediate network locations.
 
 The ping algorithm performs the following steps:
 
     # Main thread
     1   Generate the ICMP Echo packets of specified size.
     2   Encapsulate the ICMP Echo packets to IP packets of specified TTL.
     2   Transmit the IP packets to target.
     3   Register a socket callback method to handle the incoming IP packets.
     
     # Socket callback
     1   Identify type of packet.
     2   if packet.type == IP
     3       Extract source address from IP packet.
     4       Extract payload from IP packet.
     5       if payload == ICMP packet
     6           Decode type of ICMP packet
     7           case type
     8               Echo Reply:
     9                   Locate associated transmitted ICMP Echo packet.
     10                  Calculate round-trip time.
     11                  Inform delegate about the successful reception of an ICMP Echo Reply packet.
     12              Destimation Unreachable:
     13                  Inform delegate about the successful reception of an ICMP Destination Unreachable packet.
     14              Time Exceeded:
     15                  Locate associated transmitted ICMP Echo packet.
     16                  Calculate round-trip time.
     17                  Inform delegate about the successful reception of an ICMP Time Exceeded packet.
     
     # Error
     1   if operation fails
     2       Inform delegate about the error.
 
 
 */
@interface PingAlgorithm : NSObject

//------------------------------------------------------------------------------
/** @name Managing the algorithm operation */
//------------------------------------------------------------------------------


/** Initiates the ping algorithm operation.
 
 @param target      The IP address of the target network location.
 @param npackets    The number of ICMP Echo packets to be send.
 @param hops        The maximum number of times, a packet can be forwarded by an intermediate network location (value of the IP TTL field).
 @param size        The size of ICMP Echo packet.
 @param maxTries    The maximum number of tries to transmit a packet.
 
 */
- (void)performWithTarget:(NSString *)target
          numberOfPackets:(int)npackets
          maxNumberOfHops:(int)hops
        packetSizeInBytes:(int)size
         maxNumberOfTries:(int)maxTries;


/** Stops the ping algorithm operation. 
 
 The ping algorithm will stop immediately.
 
 */
- (void)stop;

/** The time allowed for the ping algorithm to complete.
 
 A value bellow 0 deactivates the timer.
 
 */
@property (nonatomic) float timeout;

//------------------------------------------------------------------------------
/** @name Managing the Delegate */
//------------------------------------------------------------------------------


/** The object that acts as the delegate of the receiving ping algorithm
 
 The delegate must adopt the PingAlgorithmDelegateProtocol protocol. The delegate is not retained.
 
 */
@property (weak, nonatomic) id <PingAlgorithmDelegateProtocol> delegate;

@end
