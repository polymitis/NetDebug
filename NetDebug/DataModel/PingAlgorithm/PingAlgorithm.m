//
//  PingAlgorithm.m
//  Trace
//
//  Created by Petros Fountas on 03/12/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>

#import "PingAlgorithm.h"

// IP header
struct iphdr {
    uint8_t     version_ihl; // Version & IHL
    uint8_t     dscp; // DSCP
    uint16_t    tlen; // Total Length
    uint16_t    identification; // Identification
    uint16_t    flags_fragoff; // Flags & Fragment Offset
    uint8_t     ttl; // TTL
    uint8_t     protocol; // Protocol
    uint16_t    hdrchksum; // Header Checksum
    uint32_t    srcaddr; // Source Address
    uint32_t    dstaddr; // Destination Address
    // options (IHL > 5)
};

// ICMP Echo request/Reply header
struct icmphdr {
    uint8_t     type; // Type
    uint8_t     code; // Code
    uint16_t    checksum; // Checksum
    uint16_t    identifier; // Identifier
    uint16_t    seqnum; // Sequence Number
};

@interface PingAlgorithm()

@property (nonatomic) CFSocketRef socket;

@property (nonatomic) struct sockaddr_in dest;

@property (strong, nonatomic) NSString *target;

@property (strong, nonatomic) NSTimer *pingTimeoutTimer;

@property (strong, nonatomic) NSDictionary *packetTxDate;

@end

@implementation PingAlgorithm

- (id)init
{
    self = [super init];
    
    if (self) {
        _socket = 0;
    }
    
    return self;
}

- (CFSocketRef)socket
{
    if (!_socket) {
        // create socket
        CFSocketContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        CFRunLoopSourceRef rls;
        _socket = CFSocketCreate(NULL,
                                 AF_INET,
                                 SOCK_DGRAM,
                                 IPPROTO_ICMP,
                                 kCFSocketReadCallBack,
                                 socketReadCallback,
                                 &context);
        rls = CFSocketCreateRunLoopSource(NULL, _socket, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        CFRelease(rls);
        
        char on = 0x1;
        // activate reception of time-exceeded error messages
        setsockopt(CFSocketGetNative(self.socket), IPPROTO_IP, IP_RECVTTL,
                   &on, sizeof(on));
    }
    return _socket;
}

- (void)setTarget:(NSString *)target
{
    // obtain address
    struct sockaddr_in dest;
    const char *addr = [target cStringUsingEncoding:NSASCIIStringEncoding];
    if (inet_pton(AF_INET, addr, &dest.sin_addr) < 0)
        [self.delegate
         pingDidFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                                                  code:errno
                                              userInfo:nil]];
    self.dest = dest;
    NSLog(@"Destination address is %s\n", addr);
}

- (NSDictionary *)packetTxDate
{
    if (!_packetTxDate) _packetTxDate = [[NSMutableDictionary alloc] init];
    return _packetTxDate;
}

- (void)stop
{
    if (self.socket) {
        CFSocketInvalidate(self.socket);
        CFRelease(self.socket);
        self.socket = nil;
        [self.delegate pingDidFailWithError:nil];
    }
    NSLog(@"Ping algorithm stopped");
}

// ICMP checksum
+ (uint16_t)chksum:(struct icmphdr *)hdr
{
    uint16_t chksum = 0x0000;
    
    // one's complement sum of all 16 bit words in the header
    for (int i = 0; i < 4; i++) {
        chksum += *((uint16_t*)hdr+i);
    }
    chksum = ~chksum; // one's complement
    
    return chksum;
}

// ICMP Echo Packet
+ (NSData *)generateICMPEchoPacketWithSize:(int)size
                            withIdentifier:(uint16_t)identifier
                        withSequenceNumber:(uint16_t)seqnum
{
    // allocate memory for packet
    int pktsize = sizeof(struct icmphdr)+(size-8); // Bytes
    void *pkt = malloc(pktsize);
    
    // construct header
    struct icmphdr hdr;
    hdr.type = 0x08; // ICMP Echo Request type
    hdr.code = 0x00;
    hdr.checksum = 0x0000;
    hdr.identifier = identifier;
    hdr.seqnum = seqnum;
    hdr.checksum = [PingAlgorithm chksum:&hdr]; // add checksum
    memcpy(pkt, &hdr, sizeof(hdr)); // move header to packet buffer
    
    // init payload to 0xFFF..
    uint8_t *pld = (uint8_t *)pkt;
    for (int i = 0; i < (size-8); i++)
        pld[i+sizeof(hdr)] = 0xFF;
    
    NSLog(@"ICMP Echo Packet [%d B] generated\n", pktsize);
    
    return [[NSData alloc] initWithBytes:pkt length:pktsize];
}

void socketReadCallback(CFSocketRef s,
                        CFSocketCallBackType type,
                        CFDataRef address,
                        const void *data,
                        void *info)
{
    NSLog(@"A packet arrived in socket");
    // get object associated with socket
    PingAlgorithm *ping  = (__bridge PingAlgorithm*) info;
    if (type == kCFSocketReadCallBack)
        [ping receivePacketFromSocket:ping->_socket]; // get packet
}

- (void)pingTimeoutOperation:(NSTimer*)theTimer
{
    NSLog(@"Timeout!");
    [self stop];
    [self.pingTimeoutTimer invalidate];
    self.pingTimeoutTimer = nil;
    NSLog(@"Timeout cleared");
}

- (void)performWithTarget:(NSString *)target
          numberOfPackets:(int)npackets
          maxNumberOfHops:(int)hops
        packetSizeInBytes:(int)size
         maxNumberOfTries:(int)maxTries
{
    self.target = target;
    struct sockaddr_in dest = self.dest;
    int s = CFSocketGetNative(self.socket);
    
    // set TTL
    int ttl = hops;
    setsockopt(s, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl));
    printf("IP TTL set to %d\n", ttl);
    
    if (self.timeout > 0) { // initiate timer
        self.pingTimeoutTimer = [NSTimer
                                 scheduledTimerWithTimeInterval:self.timeout
                                 target:self
                                 selector:@selector(pingTimeoutOperation:)
                                 userInfo:nil
                                 repeats:NO];
        NSLog(@"Timeout set to %2.2f",self.timeout);
    }
    
    // send packets
    int triesLeft = maxTries;
    // random identifier
    uint16_t identifier = (uint16_t) arc4random() >> 1; // make the msb 0
    uint16_t seqnum = identifier; // initial sequencial number
    for (int i = 0; i < npackets; i++) {
        
        // create packet
        NSData *packet = [PingAlgorithm
                          generateICMPEchoPacketWithSize:size
                          withIdentifier:identifier
                          withSequenceNumber:(++seqnum)];
        
        // send packet
        ssize_t nb = sendto(s, // socket
                            [packet bytes], // ICMP Echo packet
                            [packet length], // bytes
                            0, // no options
                            (struct sockaddr *)&dest, // destination address
                            sizeof(dest)); // destination address size
        
        // transmission error checking
        if (triesLeft > 0 && nb < 0) {
            NSLog(@"ICMP Echo packet %d failed to be transmitted",i);
            --i; // try again
            --seqnum;
            NSLog(@"%d tries left",--triesLeft);
            
        } else if (nb < 0) {
            NSLog(@"ICMP Echo packet %d failed to be transmitted",i);
            NSLog(@"Ping algorithm failed with error %s", strerror(errno));
            
            [self.pingTimeoutTimer invalidate];
            self.pingTimeoutTimer = nil;
            NSLog(@"Timeout cleared");
            
            [self.delegate
             pingDidFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                                                      code:errno
                                                  userInfo:nil]];
            return; // leave
            
        } else {
            NSLog(@"ICMP Echo packet [ID:%d,SN:%d] successfully transmitted",
                  identifier, seqnum);
            
            // save packet transmission date
            NSString *key = [NSString stringWithFormat:@"%d:%d",
                             identifier,seqnum];
            [self.packetTxDate setValue:[NSDate date] forKey:key];
            
            triesLeft = maxTries; // reset transmission tries counter
        }
    }
    
    NSLog(@"%d x ICMP Echo packets send",npackets);
    [self.delegate pingPerformedWithTarget:target
                                identifier:(int)identifier
                           numberOfPackets:npackets
                           maxNumberOfHops:hops
                         packetSizeInBytes:size];
}

- (void)receivePacketFromSocket:(CFSocketRef)socket
{
    ssize_t nb = 0; // bytes
    int s = CFSocketGetNative(socket); // get socket
    
    void *buf = malloc(65535); // rx buffer
    // receive response
    if (0 > (nb = recvfrom(s, buf, 65535, 0, NULL, NULL))) {
        [self.delegate
         pingDidFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                                                  code:errno
                                              userInfo:nil]];
        [self.pingTimeoutTimer invalidate];
        self.pingTimeoutTimer = nil;
        NSLog(@"Timeout cleared");
    }
    
    NSData *packet = [[NSData alloc] initWithBytes:buf length:65535];
    NSLog(@"Reply packet received");
    
    // process reponse
    if (nb >= (sizeof(struct iphdr) + sizeof(struct icmphdr))) {
        NSLog(@"Reply packet is an IP datagram");
        struct iphdr *ippkt = (struct iphdr *)buf;
        
        if ((ippkt->version_ihl & 0xF0) == 0x40 // IPv4
            && ippkt->protocol == 0x01) { // ICMP
            NSLog(@"Reply packet contains an ICMP packet");
            
            int ihl = (ippkt->version_ihl & 0x0F)*sizeof(uint32_t); // bytes
            if (nb >= ihl + sizeof(struct icmphdr)) {
                struct icmphdr *icmppkt = (struct icmphdr *)(buf+ihl);
                    
                // get packet source
                NSString *src = [NSString stringWithFormat:@"%d.%d.%d.%d",
                                 (ippkt->srcaddr & (0x000000FF)),
                                 (ippkt->srcaddr & (0x0000FF00)) >> 8,
                                 (ippkt->srcaddr & (0x00FF0000)) >> 16,
                                 (ippkt->srcaddr & (0xFF000000)) >> 24];
                
                // ICMP type decoder
                NSString *key;
                NSDate *txDate;
                NSTimeInterval dt;
                struct icmphdr *iicmphdr;
                switch (icmppkt->type) {
                    case 0x00: // Echo Reply
                        NSLog(@"ICMP Echo Reply [ID:%d,SN:%d] received",
                              icmppkt->identifier,icmppkt->seqnum);
                        
                        [self.pingTimeoutTimer invalidate];
                        self.pingTimeoutTimer = nil;
                        NSLog(@"Timeout cleared");
                        
                        // locate packet
                        key = [NSString stringWithFormat:@"%d:%d",
                               icmppkt->identifier,icmppkt->seqnum];
                        txDate = [self.packetTxDate valueForKey:key];
                        
                        // get packet round-trip-time
                        dt = (-1)*[txDate timeIntervalSinceNow];
                        
                        // inform delegate to handle the packet
                        [self.delegate
                         icmpPacketReceivedWithData:packet
                         identifier:(int)icmppkt->identifier
                         sequenceNumber:(int)icmppkt->seqnum
                         roundTripTime:dt
                         type:
                         PingAlgorithmICMPTypeEchoReply
                         from:src];
                        break;
                        
                    case 0x03: // Destination Unreachable
                        NSLog(@"ICMP Destination Unreachable received");
                        
                        // inform delegate to handle the packet
                        [self.delegate
                         icmpPacketReceivedWithData:packet
                         identifier:0
                         sequenceNumber:0
                         roundTripTime:0
                         type:
                         PingAlgorithmICMPTypeDestUnreach
                         from:src];
                        break;
                        
                    case 0x0B: // Time Exceeded
                        // get internal ICMP
                        iicmphdr = (struct icmphdr *)(((uint8_t *)icmppkt)+28);
                        NSLog(@"ICMP Time Exceeded for "
                              "ICMP[ID:%d,SN:%d] received",
                              iicmphdr->identifier,iicmphdr->seqnum);
                        
                        [self.pingTimeoutTimer invalidate];
                        self.pingTimeoutTimer = nil;
                        NSLog(@"Timeout cleared");
                        
                        // locate packet
                        key = [NSString stringWithFormat:@"%d:%d",
                                         iicmphdr->identifier,iicmphdr->seqnum];
                        txDate = [self.packetTxDate valueForKey:key];
                        
                        // get packet round-trip-time
                        dt = (-1)*[txDate timeIntervalSinceNow];
                        
                        // inform delegate to handle the packet
                        [self.delegate
                         icmpPacketReceivedWithData:packet
                         identifier:(int)iicmphdr->identifier
                         sequenceNumber:(int)iicmphdr->seqnum
                         roundTripTime:dt
                         type:
                         PingAlgorithmICMPTypeTimeExceeded
                         from:src];
                        break;
                        
                    default: // UKNOWN
                        NSLog(@"ICMP type is not supported");
                        
                        // inform delegate to handle the packet
                        [self.delegate
                         icmpPacketReceivedWithData:packet
                         identifier:(int)icmppkt->identifier
                         sequenceNumber:(int)icmppkt->seqnum
                         roundTripTime:dt = 0
                         type:
                         PingAlgorithmICMPTypeUnknown
                         from:src];
                        break;
                }
            }
        }
    }
}

@end
