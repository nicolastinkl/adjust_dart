# Adjust SDK for iOS

This is the [Adjust](https://adjust.com)™  SDK for iOS. Documentation is available on our help center in the following languages:



Before you begin
Here’s what you need to do before updating to SDK v5:

SDK v5 supports SDK signature verification natively. If you currently use the SDK signature library, you need to uninstall this first.
If your app targets iOS or tvOS earlier than version 12.0, you need to update your app before you can use SDK v5.

## 1. Add the SDK to your project
To use the Adjust SDK in your iOS app, you need to add it to your Xcode project.

To add the SDK using Swift’s package manager:

Select File —> Swift Packages —> Add Package Dependency
In the box that appears, enter the SDK’s GitHub address: https://github.com/adjust/ios_sdk
Select the version of the Adjust SDK you want to use in the Version dropdown. Check the releases page for the latest version.
Alternative installation methods
Cocoapods
Carthage
To add the SDK using Cocoapods, specify the version you want to use in your Podfile:

# Get pod from repository
pod 'Adjust', '~> 5.0.0'

# Get source directly from GitHub
pod 'Adjust', :git => 'https://github.com/adjust/ios_sdk.git', :tag => 'v5.0.0'

If you’re using web views in your app, add the Adjust Web Bridge by adding the following:

pod 'Adjust/AdjustWebBridge', :git => 'https://github.com/adjust/ios_sdk.git', :tag => 'v5.0.0'

##  2. Integrate the Adjust SDK
Once you’ve added the Adjust SDK to your Xcode project, you need to integrate it in your app.

Add the relevant import statements in your project files.

Swift
```Objective-C
To import the Adjust SDK, add the following to your bridging header file:
```
import AdjustSdk

##  3. Add iOS frameworks
The Adjust SDK depends on frameworks to access certain device information. To enable reading this information, add the frameworks and mark them as optional.

AdSupport.framework

Enables access to the device’s IDFA. Also enables access to LAT information on devices running iOS 14 or earlier.

Don’t add this framework if your app targets the “Kids” category.

AdServices.framework

Handles ASA attribution.

StoreKit.framework

Enables access to the SKAdNetwork framework.

Required to allow the Adjust SDK to handle communication with SKAdNetwork on devices running iOS 14 or later.

AppTrackingTransparency.framework

Required to allow the Adjust SDK to wrap user ATT consent dialog and access consent responses on devices running iOS 14 or later

Don’t add this framework if your app targets the “Kids” category

WebKit.framework

Enables the use of web views in your application

Only required if your app uses web views

##  4. Set up SDK signature
SDK v5 includes the SDK signature library. Signature protection is inactive by default. To enable it, you need to enforce signature validation.

## 5. (Optional) set up the Adjust Web Bridge
If your app uses web views, you must set up the Adjust Web Bridge to record activity inside the web view.

Integrate AdjustBridge into your app
In the Project Navigator:

Open the source file of your View Controller.
Add the import statement at the top of the file.
Add the following calls to AdjustBridge in the viewDidLoad or viewWillAppear method of your Web View Delegate:
Swift
```Objective-C
import AdjustSdk

func viewWillAppear(_ animated: Bool) {
    let webView = WKWebView(frame: view.bounds)

    // add var adjustBridge: AdjustBridge? on your interface
    adjustBridge.loadWKWebViewBridge(webView)
}
```

Integrate AdjustBridge into your web view
To use the Javascript bridge in your web view, you need to configure the bridge. Add the following Javascript code to initialize the Adjust iOS web bridge:

```Javascript
var yourAppToken = yourAppToken;
var environment = AdjustConfig.EnvironmentSandbox;
var adjustConfig = new AdjustConfig(yourAppToken, environment);
Adjust.initSdk(adjustConfig);
```

##  5. Initialize the Adjust SDK
To initialize the Adjust SDK, you need to create a config object. This object contains configuration options that control how the Adjust SDK behaves. Pass the following arguments for a minimal setup:

appToken: Your app’s token.
environment: The environment you want to run the SDK in. Set this to ADJEnvironmentSandbox.
To initialize the Adjust SDK with this config object:

Declare your config object in the didFinishLaunching or didFinishLaunchingWithOptions method of your app delegate.
Set the logLevel property on your config object to ADJLogLevelVerbose (verbose). You must enable verbose logging to retrieve device information.
Pass the config object as an argument to the initSdk method.
Swift
```Objective-C
Javascript
import AdjustSdk

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let yourAppToken = "{YourAppToken}"
        let environment = ADJEnvironmentSandbox
        let adjustConfig = ADJConfig(appToken: yourAppToken,
                                     environment: environment)

        Adjust.initSdk(adjustConfig)
       //...
        return true
 }
```
Set up your iMessage app
Important
iMessage extensions have different bundle identifiers to apps and run in a different memory space. If you configure both with the same token, the SDK returns mixed data. You must create a separate app in the Adjust dashboard for your iMessage app and use its token when initializing the Adjust SDK.

If your app targets iMessage, there are some additional settings you must configure:

If you added the Adjust SDK from source, add the ADJUST_IM=1 pre-processor macro to your iMessage project settings.
If you added the Adjust SDK as a framework, make sure to add New Copy Files Phase in your Build Phases project settings. Set the AdjustSdkIm.framework to be copied to the Frameworks folder.
Record sessions
The Adjust SDK isn’t subscribed to iOS system notifications in iMessage apps. To notify the Adjust SDK when your app has entered or left the foreground, you need to call the trackSubsessionStart and trackSubsessionEnd methods.

Add a call to trackSubsessionStart inside your didBecomeActiveWithConversation: method:

Swift
```Objective-C
func didBecomeActive(with conversation: MSConversation) {
    // Called when the extension is about to move from the inactive to active state.
    // This will happen when the extension is about to present UI.
    // Use this method to configure the extension and restore previously stored state.

    Adjust.trackSubsessionStart()
}
```

Add a call to trackSubsessionEnd inside your willResignActiveWithConversation: method:

Swift
```Objective-C
func willResignActive(with conversation: MSConversation) {
    // Called when the extension is about to move from the active to inactive state.
    // This will happen when the user dismisses the extension, changes to a different
    // conversation or quits Messages.

    // Use this method to release shared resources, save user data, invalidate timers,
    // and store enough state information to restore your extension to its current state
    // in case it is terminated later.

    Adjust.trackSubsessionEnd()
}
```

##  6. Configure the Adjust SDK
Once you’ve added your config object and initialization logic, you can configure the Adjust SDK to record information about different parts of your app. Check out the configuration reference and feature guides to set up exactly what you want to record.

##  7. Test the Adjust SDK
Now that you’ve configured the Adjust SDK to record information about your app, it’s time to test it. Adjust offers a testing console and a Device API to help you test your app.

Follow the testing guide to make sure Adjust receives the expected values back from your app.

##  8. Build your app for production
Once you’ve finished your testing, you can build your app for production. To do this, you need to update your config object.

Update the following values:

environment: Set this to ADJEnvironmentProduction.
logLevel: Choose a logging level, or disable logging completely by passing an allowSuppressLogLevel argument in your config object.
Swift
```Objective-C
import AdjustSdk

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let yourAppToken = "{YourAppToken}"
        let environment = ADJEnvironmentProduction
        let adjustConfig = ADJConfig(
            appToken: yourAppToken,
            environment: environment,
            suppressLogLevel: true)
        adjustConfig?.logLevel = ADJLogLevelVerbose
        //...
        Adjust.initSdk(adjustConfig)
       //...
        return true
}
```
You can use Xcode’s build flags to dynamically update your config depending on whether you create a debug build or a production build.

Swift
```Objective-C
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let yourAppToken = "{YourAppToken}"

        #if DEBUG
        let environment = ADJEnvironmentSandbox
        let adjustConfig = ADJConfig(
            appToken: yourAppToken,
            environment: environment)
        adjustConfig?.logLevel = ADJLogLevelVerbose

        #else
        let environment = ADJEnvironmentProduction
        let adjustConfig = ADJConfig(
            appToken: yourAppToken,
            environment: environment)
        adjustConfig?.logLevel = ADJLogLevelSuppress
        #endif
        //...
        Adjust.initSdk(adjustConfig)
        //...
        return true
}
```