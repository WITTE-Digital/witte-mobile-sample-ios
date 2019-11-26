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
    }
}
