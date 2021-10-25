import UIKit
import TapkeyMobileLib
import witte_mobile_library

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    public var tokenProvider: TokenProvider!
    public var tapkeyServiceFactory: TKMServiceFactory!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        tokenProvider = TokenProvider(withBackendAccessor: DemoBackendAccessor())

        // Create Tapkey configuration
        let config = TKMEnvironmentConfigBuilder()
            .setTenantId("wma")
            .build()

        let bleAdvertisingFormat = TKMBleAdvertisingFormatBuilder()
            .addV1Format(serviceUuid: "6e65742e-7470-6ba0-0000-060601810057")
            .addV2Format(domainId: 0x5754)
            .build()

        // Create Tapkey service factory
        tapkeyServiceFactory = TKMServiceFactoryBuilder()
                .setConfig(config)
                .setBluetoothAdvertisingFormat(bleAdvertisingFormat)
                .setTokenRefreshHandler(TokenRefreshHandler(tokenProvider: tokenProvider))                
                .build()

        return true
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Synchronize digital keys while the app is in background
        runAsyncInBackground(application, promise:tapkeyServiceFactory.notificationManager
                .pollForNotificationsAsync(cancellationToken: TKMCancellationTokens.None)
                .finallyOnUi {
                    completionHandler(UIBackgroundFetchResult.newData)
                }
        )
    }
}
