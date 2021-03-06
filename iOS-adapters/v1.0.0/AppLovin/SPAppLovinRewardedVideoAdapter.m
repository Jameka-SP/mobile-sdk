//
//  SPApplovinAdapter.m
//  SponsorPayTestApp
//
//  Created by Daniel Barden on 06/01/14.
//  Copyright (c) 2014 SponsorPay. All rights reserved.
//

#import "SPAppLovinNetwork.h"
#import "SPAppLovinRewardedVideoAdapter.h"
#import "SPLogger.h"
#import "SPConstants.h"
#import "ALSdk.h"
#import "ALIncentivizedInterstitialAd.h"
#import "ALAdLoadDelegate.h"
#import "ALAdDisplayDelegate.h"
#import "ALAdVideoPlaybackDelegate.h"
#import "ALAdRewardDelegate.h"

@interface SPAppLovinRewardedVideoAdapter() <ALAdLoadDelegate, ALAdVideoPlaybackDelegate, ALAdRewardDelegate, ALAdDisplayDelegate>

@property (nonatomic, strong) ALIncentivizedInterstitialAd *lastAd;
@property (strong, nonatomic) ALSdk *appLovinSDKInstance;
@property (copy) SPTPNVideoEventsHandlerBlock videoEventsCallback;

@property (assign, nonatomic) BOOL videoAvailable;

@property (assign, nonatomic) BOOL rewardValidationSucceeded;
@property (assign, nonatomic) BOOL wasUserRewarded;

@property (assign, nonatomic) dispatch_once_t playDispatchOnceToken;

@end

@implementation SPAppLovinRewardedVideoAdapter

@synthesize delegate = _delegate;

- (NSString *)networkName
{
    return self.network.name;
}

- (BOOL)startAdapterWithDictionary:(NSDictionary *)dict
{
    ALSdkSettings *alSDKSettings = [[ALSdkSettings alloc] init];
    self.appLovinSDKInstance = [ALSdk sharedWithKey:self.network.apiKey settings:alSDKSettings];
    self.lastAd = [[ALIncentivizedInterstitialAd alloc] initIncentivizedInterstitialWithSdk:self.appLovinSDKInstance];

    return YES;
}

- (void)checkAvailability
{
    if (!self.videoAvailable) {
        [self.lastAd preloadAndNotify:self];
        self.lastAd.adVideoPlaybackDelegate = self;
        self.lastAd.adDisplayDelegate = self;
    } else {
        [self.delegate adapter:self didReportVideoAvailable:YES];
    }
}

- (void)playVideoWithParentViewController:(UIViewController *)parentVC
{
    [self.lastAd showOver:[[UIApplication sharedApplication] keyWindow] andNotify:self];
}

#pragma mark - ALAdLoadDelegate Methods
- (void)adService:(ALAdService *)adService didLoadAd:(ALAd *)ad
{
    SPLogDebug(@"AppLovin ad Loaded");
    self.videoAvailable = YES;
    self.rewardValidationSucceeded = NO;
    self.wasUserRewarded = NO;
    self.playDispatchOnceToken = 0;
    [self.delegate adapter:self didReportVideoAvailable:YES];
}

- (void)adService:(ALAdService *)adService didFailToLoadAdWithError:(int)code
{
    SPLogDebug(@"AppLovin failed to load ads. Code: %d", code);
    [self.delegate adapter:self didReportVideoAvailable:NO];
}

#pragma mark - AlAdVideoPlaybackDelegate
- (void)videoPlaybackBeganInAd:(ALAd *)ad
{
    SPLogDebug(@"AppLovin video started playing");

    // When the app resigns active and comes back from the background, this
    // method will be called again. We want to send it just once.
    dispatch_once(&_playDispatchOnceToken, ^{
        [self.delegate adapterVideoDidStart:self];
    });

    self.videoAvailable = NO;
}

-(void)videoPlaybackEndedInAd:(ALAd *)ad
            atPlaybackPercent:(NSNumber *)percentPlayed
                 fullyWatched:(BOOL)wasFullyWatched
{
    SPLogDebug(@"AppLovin video stopped playing at %@ and %@ fully watched", percentPlayed, wasFullyWatched? @"was": @"was not");
    if (!wasFullyWatched) {
        [self.delegate adapterVideoDidAbort:self];
    } else if (self.rewardValidationSucceeded) {
        self.wasUserRewarded = YES;
        [self.delegate adapterVideoDidFinish:self];
    }
}

#pragma mark - AppLovin display delegate
- (void)ad:(ALAd *)ad wasDisplayedIn:(UIView *)view
{

}

- (void)ad:(ALAd *)ad wasClickedIn:(UIView *)view
{

}

- (void)ad:(ALAd *)ad wasHiddenIn:(UIView *)view
{
    if (self.wasUserRewarded) {
        [self.delegate adapterVideoDidClose:self];
    }
}

#pragma mark - AppLovin reward delegate
- (void)userDeclinedToViewAd:(ALAd *)ad
{
    [self.delegate adapterVideoDidAbort:self];
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didSucceedWithResponse:(NSDictionary *)response
{
    SPLogInfo(@"AppLovin reward successful");
    self.rewardValidationSucceeded = YES;
}

- (void)rewardValidationRequestForAd:(ALAd *)ad wasRejectedWithResponse:(NSDictionary *)response
{
    SPLogError(@"AppLovin reward was rejected with data %@", response);
    self.rewardValidationSucceeded = NO;
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didExceedQuotaWithResponse:(NSDictionary *)response
{
    SPLogError(@"AppLovin reward has exceeded quota %@", response);
    self.rewardValidationSucceeded = NO;
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didFailWithError:(NSInteger)responseCode
{
    SPLogError(@"AppLovin reward failed with error %d", responseCode);
    self.rewardValidationSucceeded = NO;
}

@end
