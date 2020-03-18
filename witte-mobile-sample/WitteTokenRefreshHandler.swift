//
//  WitteTokenRefreshHandler.swift
//  witte-mobile-sample
//

import Foundation
import TapkeyMobileLib

class WitteTokenRefreshHandler: NSObject, TKMTokenRefreshHandler {
    let _tokenProvider: WitteTokenProvider
    
    init(tokenProvider: WitteTokenProvider) {
        _tokenProvider = tokenProvider
    }
    
    func refreshAuthenticationAsync(userId: String, cancellationToken: TKMCancellationToken) -> TKMPromise<String> {
        return self._tokenProvider.accessToken()
    }
    
    func onRefreshFailed(userId: String) {
        // At this point you should logout the user from the app as the token refresh is permanently
        // broken and the TapkeyMobileLib is no longer able to communicate with the Tapkey backend.
        // https://developers.tapkey.io/mobile/ios/reference/TapkeyMobileLib/latest/Protocols/TKMTokenRefreshHandler.html#/s:15TapkeyMobileLib22TKMTokenRefreshHandlerP26refreshAuthenticationAsync6userId17cancellationTokenAA10TKMPromiseCySSGSS_AA015TKMCancellationM0_ptF
    }
}
