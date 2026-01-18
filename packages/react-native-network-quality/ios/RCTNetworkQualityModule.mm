// packages/react-native-network-quality/ios/RCTNetworkQualityModule.mm
//
// TurboModule implementation that bridges to Swift
//

#import "RCTNetworkQualityModule.h"
#import <React/RCTBridge+Private.h>
#import <React/RCTUtils.h>

// Forward declare the Swift implementation class
@interface RCTNetworkQualityModuleImpl : NSObject
- (void)measureNetwork:(NSDictionary *)options
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject;
- (NSDictionary *)getLastMeasurement;
- (NSDictionary *)getConnectivityStatus;
- (void)measureLatency:(NSDictionary *)options
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject;
- (void)measureThroughput:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject;
- (void)measurePacketLoss:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject;
@end

@implementation RCTNetworkQualityModule
{
    RCTNetworkQualityModuleImpl *_impl;
}

RCT_EXPORT_MODULE(RCTNetworkQualityModule)

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (instancetype)init
{
    if (self = [super init]) {
        _impl = [[RCTNetworkQualityModuleImpl alloc] init];
    }
    return self;
}

RCT_EXPORT_METHOD(measureNetwork:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [_impl measureNetwork:options resolve:resolve reject:reject];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSDictionary *, getLastMeasurement)
{
    return [_impl getLastMeasurement];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSDictionary *, getConnectivityStatus)
{
    return [_impl getConnectivityStatus];
}

RCT_EXPORT_METHOD(measureLatency:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [_impl measureLatency:options resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(measureThroughput:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [_impl measureThroughput:options resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(measurePacketLoss:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [_impl measurePacketLoss:options resolve:resolve reject:reject];
}

@end
