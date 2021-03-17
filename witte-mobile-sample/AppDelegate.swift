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
                .setbleServiceUuid(WD_BLE_SERIVCE_UUID)
                .setTenantId(WD_TENANT_ID)
                .build()

        // Create Tapkey service factory
        tapkeyServiceFactory = TKMServiceFactoryBuilder()
                .setConfig(config)
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
