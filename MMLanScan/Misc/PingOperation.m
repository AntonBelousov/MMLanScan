//
//  PingOperation.m
//  WhiteLabel-Test
//
//  Created by Michael Mavris on 03/11/2016.
//  Copyright © 2016 Miksoft. All rights reserved.
//

#import "PingOperation.h"
#import "MMDevice.h"
#import "LANProperties.h"
#import "MacFinder.h"
#import "SimplePing_withoutHost.h"

static const float PING_TIMEOUT = 1;

@interface PingOperation ()
@property (nonatomic,strong) NSString *ipStr;
@property (nonatomic,strong) NSDictionary *brandDictionary;
@property(nonatomic,strong)SimplePing *simplePing;
@property (nonatomic, copy) void (^result)(NSError  * _Nullable error, NSString  * _Nonnull ip);


@property(nonatomic,assign)BOOL stopRunLoop;
@property(nonatomic,strong)NSTimer *keepAliveTimer;
@property(nonatomic,strong)NSError *errorMessage;
@property(nonatomic,strong)NSTimer *pingTimer;

@end

@interface PingOperation()
- (void)finish;
@end

@implementation PingOperation {
    
}

-(instancetype)initWithIPToPing:(NSString*)ip andCompletionHandler:(nullable void (^)(NSError  * _Nullable error, NSString  * _Nonnull ip))result;{

    self = [super init];
    
    if (self) {
        self.name = ip;
        _ipStr= ip;
        _simplePing = [SimplePing simplePingWithIPAddress:ip];
        _simplePing.delegate = self;
        _result = result;
        _isExecuting = NO;
        _isFinished = NO;
    }
    
    return self;
};

-(void)start {

    if ([self isCancelled]) {
        [self willChangeValueForKey:@"isFinished"];
        _isFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
        
    // Run loops don't run if they don't have input sources or timers on them.  So we add a timer that we never intend to fire.
    self.keepAliveTimer = [NSTimer timerWithTimeInterval:1000000.0 target:self selector:@selector(timeout:) userInfo:nil repeats:NO];
    [ [NSRunLoop currentRunLoop] addTimer:self.keepAliveTimer forMode:NSDefaultRunLoopMode];
    
    //Ping method
    [self ping];
    
    NSTimeInterval updateInterval = 0.1f;
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:updateInterval];
    
    while (!self.stopRunLoop && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:loopUntil]) {
        loopUntil = [NSDate dateWithTimeIntervalSinceNow:updateInterval];
    }

}
-(void)ping {

    [self.simplePing sendPingWithoutHostResolving];
}
- (void)finishedPing {
    
    //Calling the completion block
    if (self.result) {
        self.result(self.errorMessage,self.name);
    }
    
    [self finish];
}

- (void)timeout:(NSTimer*)timer
{
    //This method should never get called. (just in case)
    self.errorMessage = [NSError errorWithDomain:@"Ping Timeout" code:10 userInfo:nil];
    [self finishedPing];
}

-(void)finish {

    //Removes timer from the NSRunLoop
    [self.keepAliveTimer invalidate];
    self.keepAliveTimer = nil;
    
    //Kill the while loop in the start method
    self.stopRunLoop = YES;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}
#pragma mark - Pinger delegate

// When the pinger starts, send the ping immediately
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    
    if (self.isCancelled) {
        [self finish];
        return;
    }
    
    [pinger sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
  
    [self.pingTimer invalidate];
    self.errorMessage = error;
    [self finishedPing];
}

-(void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error {
    
    [self.pingTimer invalidate];
    self.errorMessage = error;
    [self finishedPing];
}

-(void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
   
    [self.pingTimer invalidate];
    [self finishedPing];
}

-(void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    //This timer will fired pingTimeOut in case the SimplePing don't answer in the specific time
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:PING_TIMEOUT target:self selector:@selector(pingTimeOut:) userInfo:nil repeats:NO];
}

- (void)pingTimeOut:(NSTimer *)timer {
    // Move to next host
    self.errorMessage = [NSError errorWithDomain:@"Ping timeout" code:11 userInfo:nil];
    [self finishedPing];
}

@end
