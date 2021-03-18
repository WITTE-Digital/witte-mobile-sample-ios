import Foundation
import TapkeyMobileLib

/**
 This class is for demonstration purpose only and should not be part of your production app.
 The corresponding functionality should be part of your backend implementation instead.
 */
class DemoBackendAccessor: BackendAccessorProtocol {
    /**
        Your flinkey Customer-ID.
        TODO: Add your flinkey Customer Id here.
     */
    public static let FlinkeyCustomerId: Int = -1;

    /**
        Your SDK Key.
        TODO: Add your SDK Key here.
     */
    public static let FlinkeySdkKey: String = "..."

    /**
        Your flinkey-API-Key.
        TODO: Add your flinkey-API-Key here.
     */
    public static let FlinkeyApiKey: String = "..."

    /**
        User Id of one specific flinkey user (this needs to be retrieved at runtime in production apps).
        TODO: Add your flinkey user Id here.
     */
    public static let FlinkeyUserId: Int = -1;

    /**
        Your flinkey API Manager Username.
        TODO: Add your flinkey API Manager Username here.
     */
    private static let FlinkeyApiManagerUsername: String = "..."

    /**
        Your flinkey API Manager Password.
        TODO: Add your flinkey API Manager Password here.
     */
    private static let FlinkeyApiManagerPassword: String = "..."

    /**
     Called to retrieve a flinkey idToken for the current user.

     - Returns: Promise to flinkey idToken (JWT)
     */
    func requestIdToken() -> TKMPromise<String> {
        let promiseSource = TKMPromiseSource<String>()

        DemoOAuth2TokenRequest()
                .execute(withApiKey: DemoBackendAccessor.FlinkeyApiKey,
                        andApiManagerUsername: DemoBackendAccessor.FlinkeyApiManagerUsername,
                        andApiManagerPassword: DemoBackendAccessor.FlinkeyApiManagerPassword)
                .continueAsyncOnUi { accessToken -> TapkeyMobileLib.TKMPromise<String> in
                    DemoSdkTokenRequest().execute(withCustomerId: DemoBackendAccessor.FlinkeyCustomerId,
                            andApiKey: DemoBackendAccessor.FlinkeyApiKey,
                            andSdkKey: DemoBackendAccessor.FlinkeySdkKey,
                            andUserId: DemoBackendAccessor.FlinkeyUserId,
                            andAccessToken: accessToken!)
                }
                .continueOnUi { flinkeyIdToken -> Void in
                    if(!(flinkeyIdToken ?? "").isEmpty) {
                        promiseSource.setResult(flinkeyIdToken)
                    }
                    else {
                        promiseSource.setError(TKMError(errorCode: "Failed to retrieve flinkey idToken."))
                    }
                }
                .catchOnUi { error -> Void in
                    promiseSource.setError(error)
                }
                .conclude()

        return promiseSource.promise
    }
}