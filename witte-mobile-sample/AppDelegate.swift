//
//  AppDelegate.swift
//  witte-mobile-sample
//

import UIKit
import TapkeyMobileLib
import witte_mobile_library

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // Your WITTE Customer Id.
    // TODO: Add your WITTE Customer Id here.
    private let _witteCustomerId: Int = -1;

    // Your WITTE SDK Key.
    // TODO: Add your WITTE SDK Key here.
    private let _witteSdkKey: String = "Todo: Add your WITTE sdk key here"

    // Your WITTE Subscription Key.
    // TODO: Add your WITTE Subscription Key here.
    private let _witteSubscriptionKey: String = "Todo: Add your WITTE subscription key here"
    
    // User Id of one specific WITTE user (this needs to be retrieved at runtime in production apps).
    // TODO: Add your WITTE User Id here.
    private let _witteUserId = -1
    
    private var _witteConfiguration: WDConfiguration!
    private var _witteIdentityProvider: WitteIdentityProvider!
    private var _tapkeyServiceFactory: TapkeyServiceFactory!

    //
    // Customer specific configuration
    //
    public var witteConfiguration: WDConfiguration {
        get { return _witteConfiguration }
    }
    
    //
    //
    //
    public var witteIdentityProvider: WitteIdentityProvider {
        get { return _witteIdentityProvider }
    }

    //
    //
    //
    public var witteUserId: Int {
        get { return _witteUserId }
    }

    //
    // The TapkeyServiceFactory holds all needed services
    //
    public var tapkeyServiceFactory: TapkeyServiceFactory {
        get { return _tapkeyServiceFactory }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // instantiate a WITTE configuration object with user specific values
        _witteConfiguration = WDConfiguration(
                customerId: _witteCustomerId,
                sdkKey: _witteSdkKey,
                subscriptionKey: _witteSubscriptionKey)

        // instantiate the WITTE identity provider
        _witteIdentityProvider = WitteIdentityProvider(
                withConfiguration: _witteConfiguration,
                andUserId: _witteUserId)

        // instantiate the Tapkey service factory builder
        _tapkeyServiceFactory = TapkeyServiceFactoryBuilder()
                // configure the Tapkey SDK to use the WITTE tenant (wma)
                .setTenantId(tenantId: WD_TENANT_ID)
                // set the BLE service UUID of flinkey boxes
                .setBleServiceUuid(bleServiceUuid: WD_BLE_SERIVCE_UUID)
                .build();

        // register the WITTE identity provider
        _ = _tapkeyServiceFactory.getIdentityProviderRegistration().registerIdentityProvider(
                ipId: WD_IP_ID,
                identityProvider: _witteIdentityProvider)

        return true
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Let Tapkey poll for notifications.
        // Run the code via runAsyncInBackground to prevent app from sleeping while fetching is in progress.
        runAsyncInBackground(application, promise: self._tapkeyServiceFactory!.getPollingManager().poll(with: nil, with: NetTpkyMcConcurrentCancellationTokens_None)
                .finallyOnUi {
                    completionHandler(UIBackgroundFetchResult.newData);
                }
        );
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
