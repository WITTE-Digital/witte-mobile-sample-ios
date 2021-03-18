import Foundation
import TapkeyMobileLib

/**
 Used to refresh Tapkey access tokens.
 */
class TokenRefreshHandler: NSObject, TKMTokenRefreshHandler {
    let tokenProvider: TokenProvider

    init(tokenProvider: TokenProvider) {
        self.tokenProvider = tokenProvider
    }

    func refreshAuthenticationAsync(userId: String, cancellationToken: TKMCancellationToken) -> TKMPromise<String> {
        tokenProvider.accessToken()
    }

    func onRefreshFailed(userId: String) {
        // This function should never be called.
        // https://developers.tapkey.io/mobile/ios/reference/TapkeyMobileLib/latest/Protocols/TKMTokenRefreshHandler.html#/s:15TapkeyMobileLib22TKMTokenRefreshHandlerP26refreshAuthenticationAsync6userId17cancellationTokenAA10TKMPromiseCySSGSS_AA015TKMCancellationM0_ptF
    }
}
