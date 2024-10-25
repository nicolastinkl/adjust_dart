//
//  AdjustBridge.m
//  Adjust
//
//  Created by Pedro Filipe (@nonelse) on 27th April 2016.
//  Copyright © 2016-Present Adjust GmbH. All rights reserved.
//

#import "AdjustBridge.h"
#import "AdjustBridgeConstants.h"
#import "AdjustBridgeRegister.h"
#import "AdjustBridgeUtil.h"

#import <AdjustSdk/AdjustSdk.h>

@interface AdjustBridge() <WKScriptMessageHandler, AdjustDelegate>

@property BOOL isDeferredDeeplinkOpeningEnabled;
@property (nonatomic, copy) NSString *attributionCallbackName;
@property (nonatomic, copy) NSString *eventSuccessCallbackName;
@property (nonatomic, copy) NSString *eventFailureCallbackName;
@property (nonatomic, copy) NSString *sessionSuccessCallbackName;
@property (nonatomic, copy) NSString *sessionFailureCallbackName;
@property (nonatomic, copy) NSString *deferredDeeplinkCallbackName;
@property (nonatomic, copy) NSString *skanUpdatedCallbackName;
@property (nonatomic, copy) NSString *fbPixelDefaultEventToken;
@property (nonatomic, strong) NSMutableArray *urlStrategyDomains;
@property (nonatomic, strong) NSMutableDictionary *fbPixelMapping;

@property (nonatomic, strong) ADJLogger *logger;

@end

@implementation AdjustBridge

#pragma mark - Init WKWebView

- (id)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    self.isDeferredDeeplinkOpeningEnabled = YES;
    _logger = [[ADJLogger alloc] init];
    [self resetAdjustBridge];
    return self;
}

- (void)resetAdjustBridge {
    self.attributionCallbackName = nil;
    self.eventSuccessCallbackName = nil;
    self.eventFailureCallbackName = nil;
    self.sessionSuccessCallbackName = nil;
    self.sessionFailureCallbackName = nil;
    self.deferredDeeplinkCallbackName = nil;
    self.skanUpdatedCallbackName = nil;
}

#pragma mark - Public Methods

- (void)loadWKWebViewBridge:(WKWebView *_Nonnull)wkWebView {
    if ([wkWebView isKindOfClass:WKWebView.class]) {
        self.wkWebView = wkWebView;
        WKUserContentController *controller = wkWebView.configuration.userContentController;
        NSString *adjust_js = [AdjustBridgeRegister AdjustBridge_js];
        [controller addUserScript:[[WKUserScript.class alloc]
                                   initWithSource:adjust_js
                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                   forMainFrameOnly:NO]];
        [controller addScriptMessageHandler:self name:@"adjust"];
    }
}

- (UIViewController * _Nonnull) launchWKWebViewBridge:(NSString * _Nonnull) urlstring{
    return [[AdjustBridgeVC alloc] initWithUrl:urlstring];
}

- (void)augmentHybridWebView {
    NSString *fbAppId = [self getFbAppId];
    if (fbAppId == nil) {
        [self.logger error:@"FacebookAppID is not correctly configured in the pList"];
        return;
    }
    [AdjustBridgeRegister augmentHybridWebView:fbAppId];
}

#pragma mark - WKWebView Delegate

- (void)userContentController:(nonnull WKUserContentController *)userContentController
      didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSDictionary class]]) {
        [self handleMessageFromWebview:message.body];
    }
}

#pragma mark - Handling Message from WKwebview

- (void)handleMessageFromWebview:(NSDictionary<NSString *,id> *)message {
    NSString *methodName = [message objectForKey:ADJWBMethodNameKey];
    NSString *callbackId = [message objectForKey:ADJWBCallbackIdKey];
    id parameters = [message objectForKey:ADJWBParametersKey];

    if ([methodName isEqual:ADJWBInitSdkMethodName]) {
        [self initSdk:parameters];

    } else if ([methodName isEqual:ADJWBTrackEventMethodName]) {
        [self trackEvent:parameters];

    } else if ([methodName isEqual:ADJWBGetSdkVersionMethodName]) {
        __block NSString *_Nullable localSdkPrefix = [parameters objectForKey:@"sdkPrefix"];
        [Adjust sdkVersionWithCompletionHandler:^(NSString * _Nullable sdkVersion) {
            NSString *joinedSdkVersion = [NSString stringWithFormat:@"%@@%@", localSdkPrefix, sdkVersion];
            [self execJsCallbackWithId:callbackId callBackData:joinedSdkVersion];
        }];

    } else if ([methodName isEqual:ADJWBGetIdfaMethodName]) {
        [Adjust idfaWithCompletionHandler:^(NSString * _Nullable idfa) {
            [self execJsCallbackWithId:callbackId callBackData:idfa];
        }];

    }  else if ([methodName isEqual:ADJWBGetIdfvMethodName]) {
        [Adjust idfvWithCompletionHandler:^(NSString * _Nullable idfv) {
            [self execJsCallbackWithId:callbackId callBackData:idfv];
        }];

    } else if ([methodName isEqual:ADJWBGetAdidMethodName]) {
        [Adjust adidWithCompletionHandler:^(NSString * _Nullable adid) {
            [self execJsCallbackWithId:callbackId callBackData:adid];
        }];

    } else if ([methodName isEqual:ADJWBGetAttributionMethodName]) {
        [Adjust attributionWithCompletionHandler:^(ADJAttribution * _Nullable attribution) {
            [self execJsCallbackWithId:callbackId callBackData:[attribution dictionary]];
        }];

    } else if ([methodName isEqual:ADJWBIsEnabledMethodName]) {
        [Adjust isEnabledWithCompletionHandler:^(BOOL isEnabled) {
            [self execJsCallbackWithId:callbackId callBackData:@(isEnabled).description];
        }];

    } else if ([methodName isEqual:ADJWBRequestAppTrackingMethodName]) {
        [Adjust requestAppTrackingAuthorizationWithCompletionHandler:^(NSUInteger status) {
            [self execJsCallbackWithId:callbackId callBackData:@(status).description];
        }];

    } else if ([methodName isEqual:ADJWBAppTrackingAuthorizationStatus]) {
        int appTrackingAuthorizationStatus = [Adjust appTrackingAuthorizationStatus];
        [self execJsCallbackWithId:callbackId callBackData:@(appTrackingAuthorizationStatus).description];

    } else if ([methodName isEqual:ADJWBSwitchToOfflineModeMethodName]) {
        [Adjust switchToOfflineMode];

    } else if ([methodName isEqual:ADJWBSwitchBackToOnlineMode]) {
        [Adjust switchBackToOnlineMode];

    } else if ([methodName isEqual:ADJWBEnableMethodName]) {
        [Adjust enable];

    } else if ([methodName isEqual:ADJWBDisableMethodName]) {
        [Adjust disable];

    } else if ([methodName isEqual:ADJWBTrackSubsessionStartMethodName]) {
        [Adjust trackSubsessionStart];

    } else if ([methodName isEqual:ADJWBTrackSubsessionEndMethodName]) {
        [Adjust trackSubsessionEnd];

    } else if ([methodName isEqual:ADJWBTrackMeasurementConsentMethodName]) {
        if (![parameters isKindOfClass:[NSNumber class]]) {
            return;
        }
        [Adjust trackMeasurementConsent:[(NSNumber *)parameters boolValue]];

    } else if ([methodName isEqual:ADJWBAddGlobalCallbackParameterMethodName]) {
        NSString *key = [parameters objectForKey:ADJWBKvKeyKey];
        NSString *value = [parameters objectForKey:ADJWBKvValueKey];
        [Adjust addGlobalCallbackParameter:value forKey:key];

    } else if ([methodName isEqual:ADJWBRemoveGlobalCallbackParameterMethodName]) {
        if (![parameters isKindOfClass:[NSString class]]) {
            return;
        }
        [Adjust removeGlobalCallbackParameterForKey:(NSString *)parameters];

    } else if ([methodName isEqual:ADJWBRemoveGlobalCallbackParametersMethodName]) {
        [Adjust removeGlobalCallbackParameters];

    } else if ([methodName isEqual:ADJWBAddGlobalPartnerParameterMethodName]) {
        NSString *key = [parameters objectForKey:ADJWBKvKeyKey];
        NSString *value = [parameters objectForKey:ADJWBKvValueKey];
        [Adjust addGlobalPartnerParameter:value forKey:key];

    } else if ([methodName isEqual:ADJWBRemoveGlobalPartnerParameterMethodName]) {
        if (![parameters isKindOfClass:[NSString class]]) {
            return;
        }
        [Adjust removeGlobalPartnerParameterForKey:(NSString *)parameters];

    } else if ([methodName isEqual:ADJWBRemoveGlobalPartnerParametersMethodName]) {
        [Adjust removeGlobalPartnerParameters];

    } else if ([methodName isEqual:ADJWBGdprForgetMeMethodName]) {
        [Adjust gdprForgetMe];

    } else if ([methodName isEqual:ADJWBTrackThirdPartySharingMethodName]) {
        [self trackThirdPartySharing:parameters];

    } else if ([methodName isEqual:ADJWBSetTestOptionsMethodName]) {
        [self setTestOptions:parameters];

    } else if ([methodName isEqual:ADJWBFBPixelEventMethodName]) {
        [self trackFbPixelEvent:parameters];
    }
}

- (void)initSdk:(id)parameters {
    NSString *appToken = [parameters objectForKey:ADJWBAppTokenConfigKey];
    NSString *environment = [parameters objectForKey:ADJWBEnvironmentConfigKey];
    NSString *allowSuppressLogLevel = [parameters objectForKey:ADJWBAllowSuppressLogLevelConfigKey];
    NSString *sdkPrefix = [parameters objectForKey:ADJWBSdkPrefixConfigKey];
    NSString *defaultTracker = [parameters objectForKey:ADJWBDefaultTrackerConfigKey];
    NSString *externalDeviceId = [parameters objectForKey:ADJWBExternalDeviceIdConfigKey];
    NSString *logLevel = [parameters objectForKey:ADJWBLogLevelConfigKey];
    NSNumber *sendInBackground = [parameters objectForKey:ADJWBSendInBackgroundConfigKey];
    NSNumber *isCostDataInAttributionEnabled = [parameters objectForKey:ADJWBNeedsCostConfigKey];
    NSNumber *isAdServicesEnabled = [parameters objectForKey:ADJWBAllowAdServicesInfoReadingConfigKey];
    NSNumber *isIdfaReadingAllowed = [parameters objectForKey:ADJWBIsIdfaReadingAllowedConfigKey];
    NSNumber *isSkanAttributionHandlingEnabled = [parameters objectForKey:ADJWBIsSkanAttributionHandlingEnabledConfigKey];
    NSNumber *isDeferredDeeplinkOpeningEnabled = [parameters objectForKey:ADJWBIsDeferredDeeplinkOpeningEnabledConfigKey];
    NSNumber *isCoppaComplianceEnabled = [parameters objectForKey:ADJWBIsCoppaComplianceEnabledConfigKey];
    NSNumber *shouldReadDeviceInfoOnce = [parameters objectForKey:ADJWBReadDeviceInfoOnceEnabledConfigKey];
    NSNumber *attConsentWaitingSeconds = [parameters objectForKey:ADJWBAttConsentWaitingSecondsConfigKey];
    NSNumber *eventDeduplicationIdsMaxSize = [parameters objectForKey:ADJWBEventDeduplicationIdsMaxSizeConfigKey];

    id urlStrategyDomains = [parameters objectForKey:ADJWBUseStrategyDomainsConfigKey];
    NSNumber *useSubdomains = [parameters objectForKey:ADJWBUseSubdomainsConfigKey];
    NSNumber *isDataResidency = [parameters objectForKey:ADJWBIsDataResidencyConfigKey];

    //Adjust's callbacks
    NSString *attributionCallback = [parameters objectForKey:ADJWBAttributionCallbackConfigKey];
    NSString *eventSuccessCallback = [parameters objectForKey:ADJWBEventSuccessCallbackConfigKey];
    NSString *eventFailureCallback = [parameters objectForKey:ADJWBEventFailureCallbackConfigKey];
    NSString *sessionSuccessCallback = [parameters objectForKey:ADJWBSessionSuccessCallbackConfigKey];
    NSString *sessionFailureCallback = [parameters objectForKey:ADJWBSessionFailureCallbackConfigKey];
    NSString *skanUpdatedCallback = [parameters objectForKey:ADJWBSkanUpdatedCallbackConfigKey];
    NSString *deferredDeeplinkCallback = [parameters objectForKey:ADJWBDeferredDeeplinkCallbackConfigKey];

    //Fb parameters
    NSString *fbPixelDefaultEventToken = [parameters objectForKey:ADJWBFbPixelDefaultEventTokenConfigKey];
    id fbPixelMapping = [parameters objectForKey:ADJWBFbPixelMappingConfigKey];

    ADJConfig *adjustConfig;
    if ([AdjustBridgeUtil isFieldValid:allowSuppressLogLevel]) {
        adjustConfig = [[ADJConfig alloc] initWithAppToken:appToken
                                               environment:environment
                                          suppressLogLevel:[allowSuppressLogLevel boolValue]];
    } else {
        adjustConfig = [[ADJConfig alloc] initWithAppToken:appToken environment:environment];
    }

    if (![adjustConfig isValid]) {
        return;
    }

    if ([AdjustBridgeUtil isFieldValid:sdkPrefix]) {
        [adjustConfig setSdkPrefix:sdkPrefix];
    }
    if ([AdjustBridgeUtil isFieldValid:defaultTracker]) {
        [adjustConfig setDefaultTracker:defaultTracker];
    }
    if ([AdjustBridgeUtil isFieldValid:externalDeviceId]) {
        [adjustConfig setExternalDeviceId:externalDeviceId];
    }
    if ([AdjustBridgeUtil isFieldValid:logLevel]) {
        [adjustConfig setLogLevel:[ADJLogger logLevelFromString:[logLevel lowercaseString]]];
    }
    if ([AdjustBridgeUtil isFieldValid:sendInBackground]) {
        if ([sendInBackground boolValue] == YES) {
            [adjustConfig enableSendingInBackground];
        }
    }
    if ([AdjustBridgeUtil isFieldValid:isCostDataInAttributionEnabled]) {
        if ([isCostDataInAttributionEnabled boolValue] == YES) {
            [adjustConfig enableCostDataInAttribution];
        }
    }
    if ([AdjustBridgeUtil isFieldValid:isAdServicesEnabled]) {
        if ([isAdServicesEnabled boolValue] == NO) {
            [adjustConfig disableAdServices];
        }
    }
    if ([AdjustBridgeUtil isFieldValid:isCoppaComplianceEnabled]) {
        if ([isCoppaComplianceEnabled boolValue] == YES) {
            [adjustConfig enableCoppaCompliance];
        }
    }
    if ([AdjustBridgeUtil isFieldValid:isDeferredDeeplinkOpeningEnabled]) {
        self.isDeferredDeeplinkOpeningEnabled = [isDeferredDeeplinkOpeningEnabled boolValue];
    }

    if ([AdjustBridgeUtil isFieldValid:isIdfaReadingAllowed]) {
        if ([isIdfaReadingAllowed boolValue] == NO) {
            [adjustConfig disableIdfaReading];
        }
    }

    if ([AdjustBridgeUtil isFieldValid:attConsentWaitingSeconds]) {
        [adjustConfig setAttConsentWaitingInterval:[attConsentWaitingSeconds doubleValue]];
    }

    if ([AdjustBridgeUtil isFieldValid:isSkanAttributionHandlingEnabled]) {
        if ([isSkanAttributionHandlingEnabled boolValue] == NO) {
            [adjustConfig disableSkanAttribution];
        }
    }

    if ([AdjustBridgeUtil isFieldValid:shouldReadDeviceInfoOnce]) {
        if ([shouldReadDeviceInfoOnce boolValue] == YES) {
            [adjustConfig enableDeviceIdsReadingOnce];
        }
    }

    if ([AdjustBridgeUtil isFieldValid:eventDeduplicationIdsMaxSize]) {
        [adjustConfig setEventDeduplicationIdsMaxSize:[eventDeduplicationIdsMaxSize integerValue]];
    }

    //fb parameters handling
    if ([AdjustBridgeUtil isFieldValid:fbPixelDefaultEventToken]) {
        self.fbPixelDefaultEventToken = fbPixelDefaultEventToken;
    }

    if ([fbPixelMapping count] > 0) {
        self.fbPixelMapping = [[NSMutableDictionary alloc] initWithCapacity:[fbPixelMapping count] / 2];
    }

    for (int i = 0; i < [fbPixelMapping count]; i += 2) {
        NSString *key = [[fbPixelMapping objectAtIndex:i] description];
        NSString *value = [[fbPixelMapping objectAtIndex:(i + 1)] description];
        [self.fbPixelMapping setObject:value forKey:key];
    }

    if ([AdjustBridgeUtil isFieldValid:attributionCallback]) {
        self.attributionCallbackName = attributionCallback;
    }
    if ([AdjustBridgeUtil isFieldValid:eventSuccessCallback]) {
        self.eventSuccessCallbackName = eventSuccessCallback;
    }
    if ([AdjustBridgeUtil isFieldValid:eventFailureCallback]) {
        self.eventFailureCallbackName = eventFailureCallback;
    }
    if ([AdjustBridgeUtil isFieldValid:sessionSuccessCallback]) {
        self.sessionSuccessCallbackName = sessionSuccessCallback;
    }
    if ([AdjustBridgeUtil isFieldValid:sessionFailureCallback]) {
        self.sessionFailureCallbackName = sessionFailureCallback;
    }
    if ([AdjustBridgeUtil isFieldValid:deferredDeeplinkCallback]) {
        self.deferredDeeplinkCallbackName = deferredDeeplinkCallback;
    }
    if ([AdjustBridgeUtil isFieldValid:skanUpdatedCallback]) {
        self.skanUpdatedCallbackName = skanUpdatedCallback;
    }

    // set self as delegate if any callback is configured
    // change to swizzle the methods in the future
    if (self.attributionCallbackName != nil
        || self.eventSuccessCallbackName != nil
        || self.eventFailureCallbackName != nil
        || self.sessionSuccessCallbackName != nil
        || self.sessionFailureCallbackName != nil
        || self.deferredDeeplinkCallbackName != nil
        || self.skanUpdatedCallbackName != nil) {
        [adjustConfig setDelegate:self];
    }

    // URL strategy
    if (urlStrategyDomains != nil && [urlStrategyDomains count] > 0) {
        self.urlStrategyDomains = [[NSMutableArray alloc] initWithCapacity:[urlStrategyDomains count]];
        for (int i = 0; i < [urlStrategyDomains count]; i += 1) {
            NSString *domain = [[urlStrategyDomains objectAtIndex:i] description];
            [self.urlStrategyDomains addObject:domain];
        }
    }
    if ([AdjustBridgeUtil isFieldValid:useSubdomains] && [AdjustBridgeUtil isFieldValid:isDataResidency]) {
        [adjustConfig setUrlStrategy:(NSArray *)self.urlStrategyDomains
                       useSubdomains:[useSubdomains boolValue]
                     isDataResidency:[isDataResidency boolValue]];
    }

    [Adjust initSdk:adjustConfig];
}

- (void)trackEvent:(NSDictionary *)parameters {
    NSString *eventToken = [parameters objectForKey:ADJWBEventTokenEventKey];
    NSString *revenue = [parameters objectForKey:ADJWBRevenueEventKey];
    NSString *currency = [parameters objectForKey:ADJWBCurrencyEventKey];
    NSString *deduplicationId = [parameters objectForKey:ADJWBDeduplicationIdEventKey];
    NSString *callbackId = [parameters objectForKey:ADJWBCallbackIdEventKey];
    id callbackParameters = [parameters objectForKey:ADJWBCallbackParametersEventKey];
    id partnerParameters = [parameters objectForKey:ADJWBPartnerParametersEventKey];

    ADJEvent *_Nonnull adjEvent = [[ADJEvent alloc] initWithEventToken:eventToken];

    if ([AdjustBridgeUtil isFieldValid:callbackId]) {
        [adjEvent setCallbackId:callbackId];
    }

    if ([AdjustBridgeUtil isFieldValid:deduplicationId]) {
        [adjEvent setDeduplicationId:deduplicationId];
    }

    if ([AdjustBridgeUtil isFieldValid:revenue] && [AdjustBridgeUtil isFieldValid:currency]) {
        double revenueValue = [revenue doubleValue];
        [adjEvent setRevenue:revenueValue currency:currency];
    }
    for (int i = 0; i < [callbackParameters count]; i += 2) {
        NSString *key = [[callbackParameters objectAtIndex:i] description];
        NSString *value = [[callbackParameters objectAtIndex:(i + 1)] description];
        [adjEvent addCallbackParameter:key value:value];
    }
    for (int i = 0; i < [partnerParameters count]; i += 2) {
        NSString *key = [[partnerParameters objectAtIndex:i] description];
        NSString *value = [[partnerParameters objectAtIndex:(i + 1)] description];
        [adjEvent addPartnerParameter:key value:value];
    }

    [Adjust trackEvent:adjEvent];
}

- (void)trackThirdPartySharing:(NSDictionary *)parameters {
    id isEnabledO = [parameters objectForKey:ADJWBIsEnabledTPSKey];
    id granularOptions = [parameters objectForKey:ADJWBGranularOptionsTPSKey];
    id partnerSharingSettings = [parameters objectForKey:ADJWBPartnerSharingSettingTPSKey];

    NSNumber *isEnabled = nil;
    if ([isEnabledO isKindOfClass:[NSNumber class]]) {
        isEnabled = (NSNumber *)isEnabledO;
    }

    ADJThirdPartySharing *adjustThirdPartySharing = [[ADJThirdPartySharing alloc] initWithIsEnabled:isEnabled];

    for (int i = 0; i < [granularOptions count]; i += 3) {
        NSString *partnerName = [[granularOptions objectAtIndex:i] description];
        NSString *key = [[granularOptions objectAtIndex:(i + 1)] description];
        NSString *value = [[granularOptions objectAtIndex:(i + 2)] description];
        [adjustThirdPartySharing addGranularOption:partnerName key:key value:value];
    }
    for (int i = 0; i < [partnerSharingSettings count]; i += 3) {
        NSString *partnerName = [[partnerSharingSettings objectAtIndex:i] description];
        NSString *key = [[partnerSharingSettings objectAtIndex:(i + 1)] description];
        BOOL value = [[partnerSharingSettings objectAtIndex:(i + 2)] boolValue];
        [adjustThirdPartySharing addPartnerSharingSetting:partnerName key:key value:value];
    }

    [Adjust trackThirdPartySharing:adjustThirdPartySharing];
}

- (void)setTestOptions:(NSDictionary *)data {
    [Adjust setTestOptions:[AdjustBridgeUtil getTestOptions:data]];

    NSNumber *teardown = [data objectForKey:@"teardown"];
    if ([AdjustBridgeUtil isFieldValid:teardown] && [teardown boolValue] == YES) {
        [self resetAdjustBridge];
    }
}

#pragma mark - Native to Javascript Callback Handling

- (void)execJsCallbackWithId:(NSString *)callbackId callBackData:(id)data {
    NSString *callbackParamString;
    if ([data isKindOfClass:[NSMutableDictionary class]] || [data isKindOfClass:[NSDictionary class]]) {
        callbackParamString = [AdjustBridgeUtil serializeData:data pretty:NO];
    }

    if ([data isKindOfClass:[NSString class]]){
        callbackParamString = data;
    }

    NSString *jsExecCommand = [NSString stringWithFormat:@"%@('%@')", callbackId,
                               callbackParamString];

    [AdjustBridgeUtil launchInMainThread:^{
        [self.wkWebView evaluateJavaScript:jsExecCommand completionHandler:nil];
    }];
}

#pragma mark - AdjustDelegate methods

- (void)adjustAttributionChanged:(ADJAttribution *)attribution {
    if (self.attributionCallbackName == nil) {
        return;
    }
    [self execJsCallbackWithId:self.attributionCallbackName
                  callBackData:[attribution dictionary]];
}

- (void)adjustEventTrackingSucceeded:(ADJEventSuccess *)eventSuccessResponseData {
    if (self.eventSuccessCallbackName == nil) {
        return;
    }

    NSMutableDictionary *eventSuccessResponseDataDictionary = [NSMutableDictionary dictionary];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.message
                                          forKey:@"message"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.timestamp
                                          forKey:@"timestamp"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.adid
                                          forKey:@"adid"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.eventToken
                                          forKey:@"eventToken"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.callbackId
                                          forKey:@"callbackId"];

    NSString *jsonResponse = [AdjustBridgeUtil
                              convertJsonDictionaryToNSString:eventSuccessResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [eventSuccessResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self execJsCallbackWithId:self.eventSuccessCallbackName
                  callBackData:eventSuccessResponseDataDictionary];
}

- (void)adjustEventTrackingFailed:(ADJEventFailure *)eventFailureResponseData {
    if (self.eventFailureCallbackName == nil) {
        return;
    }

    NSMutableDictionary *eventFailureResponseDataDictionary = [NSMutableDictionary dictionary];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.message
                                          forKey:@"message"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.timestamp
                                          forKey:@"timestamp"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.adid
                                          forKey:@"adid"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.eventToken
                                          forKey:@"eventToken"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.callbackId
                                          forKey:@"callbackId"];
    [eventFailureResponseDataDictionary setValue:[NSNumber numberWithBool:eventFailureResponseData.willRetry]
                                          forKey:@"willRetry"];

    NSString *jsonResponse = [AdjustBridgeUtil
                              convertJsonDictionaryToNSString:eventFailureResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [eventFailureResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self execJsCallbackWithId:self.eventFailureCallbackName
                  callBackData:eventFailureResponseDataDictionary];
}

- (void)adjustSessionTrackingSucceeded:(ADJSessionSuccess *)sessionSuccessResponseData {
    if (self.sessionSuccessCallbackName == nil) {
        return;
    }

    NSMutableDictionary *sessionSuccessResponseDataDictionary = [NSMutableDictionary dictionary];
    [sessionSuccessResponseDataDictionary setValue:sessionSuccessResponseData.message
                                            forKey:@"message"];
    [sessionSuccessResponseDataDictionary setValue:sessionSuccessResponseData.timestamp
                                            forKey:@"timestamp"];
    [sessionSuccessResponseDataDictionary setValue:sessionSuccessResponseData.adid
                                            forKey:@"adid"];

    NSString *jsonResponse = [AdjustBridgeUtil
                              convertJsonDictionaryToNSString:sessionSuccessResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [sessionSuccessResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self execJsCallbackWithId:self.sessionSuccessCallbackName
                  callBackData:sessionSuccessResponseDataDictionary];
}

- (void)adjustSessionTrackingFailed:(ADJSessionFailure *)sessionFailureResponseData {
    if (self.sessionFailureCallbackName == nil) {
        return;
    }

    NSMutableDictionary *sessionFailureResponseDataDictionary = [NSMutableDictionary dictionary];
    [sessionFailureResponseDataDictionary setValue:sessionFailureResponseData.message
                                            forKey:@"message"];
    [sessionFailureResponseDataDictionary setValue:sessionFailureResponseData.timestamp
                                            forKey:@"timestamp"];
    [sessionFailureResponseDataDictionary setValue:sessionFailureResponseData.adid
                                            forKey:@"adid"];
    [sessionFailureResponseDataDictionary setValue:[NSNumber numberWithBool:sessionFailureResponseData.willRetry]
                                            forKey:@"willRetry"];

    NSString *jsonResponse = [AdjustBridgeUtil
                              convertJsonDictionaryToNSString:sessionFailureResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [sessionFailureResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self execJsCallbackWithId:self.sessionFailureCallbackName
                  callBackData:sessionFailureResponseDataDictionary];
}

- (BOOL)adjustDeferredDeeplinkReceived:(NSURL *)deeplink {
    if (self.deferredDeeplinkCallbackName) {
        [self execJsCallbackWithId:self.deferredDeeplinkCallbackName
                      callBackData:[deeplink absoluteString]];
    }
    return self.isDeferredDeeplinkOpeningEnabled;
}

- (void)adjustSkanUpdatedWithConversionData:(nonnull NSDictionary<NSString *, NSString *> *)data {
    if (self.skanUpdatedCallbackName == nil) {
        return;
    }

    NSMutableDictionary *skanUpdatedDictionary = [NSMutableDictionary dictionary];
    [skanUpdatedDictionary setValue:data[@"conversion_value"] forKey:@"conversionValue"];
    [skanUpdatedDictionary setValue:data[@"coarse_value"] forKey:@"coarseValue"];
    [skanUpdatedDictionary setValue:data[@"lock_window"] forKey:@"lockWindow"];
    [skanUpdatedDictionary setValue:data[@"error"] forKey:@"error"];

    [self execJsCallbackWithId:self.skanUpdatedCallbackName
                  callBackData:skanUpdatedDictionary];
}

#pragma mark - FB Pixel event handling

- (void)trackFbPixelEvent:(id)data {
    NSString *pixelID = [data objectForKey:@"pixelID"];
    if (pixelID == nil) {
        [self.logger error:@"Can't bridge an event without a referral Pixel ID. Check your webview Pixel configuration"];
        return;
    }
    NSString *evtName = [data objectForKey:@"evtName"];
    NSString *eventToken = [self getEventTokenFromFbPixelEventName:evtName];
    if (eventToken == nil) {
        [self.logger debug:@"No mapping found for the fb pixel event %@, trying to fall back to the default event token", evtName];
        eventToken = self.fbPixelDefaultEventToken;
    }
    if (eventToken == nil) {
        [self.logger  debug:@"There is not a default event token configured or a mapping found for event named: '%@'. It won't be tracked as an adjust event", evtName];
        return;
    }

    ADJEvent *fbPixelEvent = [[ADJEvent alloc] initWithEventToken:eventToken];
    if (![fbPixelEvent isValid]) {
        return;
    }

    id customData = [data objectForKey:@"customData"];
    [fbPixelEvent addPartnerParameter:@"_fb_pixel_referral_id" value:pixelID];
    // [fbPixelEvent addPartnerParameter:@"_eventName" value:evtName];
    if ([customData isKindOfClass:[NSString class]]) {
        NSError *jsonParseError = nil;
        NSDictionary *params = [NSJSONSerialization JSONObjectWithData:[customData dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:NSJSONReadingMutableContainers
                                                                 error:&jsonParseError];
        [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *keyS = [key description];
            NSString *valueS = [obj description];
            [fbPixelEvent addPartnerParameter:keyS value:valueS];
        }];
    }

    [Adjust trackEvent:fbPixelEvent];
}

- (NSString *)getEventTokenFromFbPixelEventName:(NSString *)fbPixelEventName {
    if (self.fbPixelMapping == nil) {
        return nil;
    }
    return [self.fbPixelMapping objectForKey:fbPixelEventName];
}

- (NSString *)getFbAppId {
    NSString *facebookLoggingOverrideAppID =
    [self getValueFromBundleByKey:@"FacebookLoggingOverrideAppID"];
    if (facebookLoggingOverrideAppID != nil) {
        return facebookLoggingOverrideAppID;
    }
    return [self getValueFromBundleByKey:@"FacebookAppID"];
}

- (NSString *)getValueFromBundleByKey:(NSString *)key {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:key] copy];
}


@end

 //
@interface AdjustBridgeVC()<WKScriptMessageHandler,WKNavigationDelegate,WKUIDelegate>
@end

@implementation AdjustBridgeVC

- (instancetype _Nullable)initWithUrl:(NSString * _Nonnull)url {
    self = [super init];
    if (self) {
        // Configuration and initialization code...
        [self setupWebViewWithURL:url];
    }
    return self;
}

- (void)setupWebViewWithURL:(NSString *)url {
    
    // 设置导航栏颜色
       self.navigationController.navigationBar.barTintColor = [UIColor systemBlueColor];
       self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
       
       // 创建关闭按钮
       UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeButtonClicked)];
       self.navigationItem.leftBarButtonItem = closeButton;
       
       // 创建并配置WKWebView
       WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
       WKUserContentController *userContent = [[WKUserContentController alloc] init];
       
       NSString *jsCode = @"window.jsBridge = {postMessage: function(name, data) {window.webkit.messageHandlers.Post.postMessage({name,data})}};";
       WKUserScript *zuowan = [[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
       [userContent addUserScript:zuowan];
       [userContent addScriptMessageHandler:self name:@"Post"];
       config.userContentController = userContent;
       
       self.webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:config];
       self.webView.navigationDelegate = self;
       self.webView.UIDelegate = self;
       [self.view addSubview:self.webView];
       
       NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
       [self.webView loadRequest:request];
       
       // 创建加载提示器
       if (@available(iOS 13.0, *)) {
           self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
       } else {
           self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
       }
       self.loadingView.frame = self.webView.frame;
       self.loadingView.color = [UIColor blackColor];
       [self.view addSubview:self.loadingView];
       [self.loadingView startAnimating];
       
       // 启用AutoLayout
       [self.webView setTranslatesAutoresizingMaskIntoConstraints:NO];
       NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
       NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
       NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
       NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
       [NSLayoutConstraint activateConstraints:@[topConstraint, leftConstraint, bottomConstraint, rightConstraint]];
       
       // 关闭safe area的自动布局
       self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
   }

   - (void)closeButtonClicked {
       if (self.closeBlock) {
           self.closeBlock();
       }
       [self dismissViewControllerAnimated:YES completion:nil];
   }

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message { 
    
    if ([message.name isEqualToString:@"Post"]) {
        NSDictionary *body = message.body;
        NSString *name = [body objectForKey:@"name"];
        NSString *dataString = [body objectForKey:@"data"];
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        
        // 尝试将data字符串转换为JSON
        if (dataString) {
            NSData *subData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:subData options:0 error:&error];
            if (!error && [json isKindOfClass:[NSDictionary class]]) {
                [dic addEntriesFromDictionary:json];
            }
        }
        if (name &&  ![name isEqualToString:@"openWindow"]) {
            // 记录点击事件或其他逻辑
            self.recharge = name;
            [self sendAppsFlyer:name withValues:dic];
            return;
        }
         
        NSString *urlString = [dic objectForKey:@"url"];
        if (urlString.length > 10) {
            [self openWindow:urlString];
        }
    }
}
- (void)openWindow:(NSString *)urlString {
    NSString *otherStr = urlString;
    NSString *newUrlString = urlString;
    
    if ([otherStr containsString:@"gaming-curacao"]) {
        newUrlString = [otherStr stringByReplacingOccurrencesOfString:@"gaming-curacao" withString:@"appsflyerssdk"];
        
        AdjustBridgeVC *gameWebVC = [[AdjustBridgeVC alloc] initWithUrl:newUrlString];
         
        gameWebVC.closeBlock = ^{
            NSString *jsMessage = @"window.closeGame();";
            [self.webView evaluateJavaScript:jsMessage completionHandler:nil];
        };
        
        UINavigationController *gameController = [[UINavigationController alloc] initWithRootViewController:gameWebVC];
        gameController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:gameController animated:NO completion:nil];
    } else {
        NSURL *url = [NSURL URLWithString:urlString];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame) {
        //NSURL *url = navigationAction.request.URL;
    }
    return nil;
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    NSString *authentisaMethod = challenge.protectionSpace.authenticationMethod;
    
    if ([authentisaMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = nil;
        if (challenge.protectionSpace.serverTrust) {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            
        }
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        // 从XIB加载时的初始化代码
    }
    return self;
}

- (void)animateView:(UIView *)view duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion {
    [UIView animateWithDuration:duration delay:delay options:options animations:animations completion:completion];
}
- (void)sendAppsFlyer:(NSString *)name withValues:(NSDictionary *)message {
    // AppsFlyer事件上报逻辑
    // 这里需要根据实际的AppsFlyer SDK for Objective-C进行事件上报
    //[AppsFlyerLib.shared() logEvent:name withValues:message];
    _eventblock(name);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    [self.loadingView stopAnimating];
}
 
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    [self.loadingView stopAnimating];
}



@end
