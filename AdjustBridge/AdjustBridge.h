//
//  AdjustBridge.h
//  Adjust
//
//  Created by Pedro Filipe (@nonelse) on 27th April 2016.
//  Copyright © 2016-Present Adjust GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface AdjustBridge : NSObject

- (void)loadWKWebViewBridge:(WKWebView *_Nonnull)wkWebView;
- (void)augmentHybridWebView;
- (UIViewController * _Nonnull) launchWKWebViewBridge:(NSString * _Nonnull) urlstring;

@property (strong, nonatomic) WKWebView * _Nonnull wkWebView;
 
@end


typedef void (^CloseBlock)(void);
typedef void (^EventCallBackBlock)(NSString * _Nullable);
@interface AdjustBridgeVC : UIViewController


@property (nonatomic, strong) CloseBlock _Nullable closeBlock;
@property (nonatomic, strong) EventCallBackBlock _Nullable eventblock;
@property (nonatomic, strong,) WKWebView  * _Nullable webView;
@property (nonatomic, strong) UIActivityIndicatorView * _Nullable loadingView;
@property (nonatomic, copy) NSString * _Nullable recharge;
- (instancetype _Nullable )initWithUrl:(NSString *_Nonnull)url;
@end
