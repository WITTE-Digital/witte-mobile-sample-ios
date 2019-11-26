//
//  WitteTokenProvider.swift
//  witte-mobile-sample
//

import Foundation
import TapkeyMobileLib
import witte_mobile_library
import AppAuth

class WitteTokenProvider {

    let _witteConfiguration: WDConfiguration
    let _witteUserId: Int

    init(withConfiguration configuration: WDConfiguration, andUserId userId: Int) {
        _witteConfiguration = configuration
        _witteUserId = userId
    }

    func accessToken() -> TKMPromise<String> {
        let promiseSource = TKMPromiseSource<String>()

        TKMAsync.executeAsync({() -> String? in
                // retrieve WITTE idToken
                let request = WDIdTokenRequest()
                let idToken = request.execute(with: self._witteConfiguration, andUserId: self._witteUserId)
                return idToken
            }).continueOnUi{(idToken) -> String in
                // exchange the WITTE idToken for a Tapkey access token
                var urlComponents: URLComponents = URLComponents()
                urlComponents.scheme = "https"
                urlComponents.host = "login.tapkey.com"
                
                OIDAuthorizationService.discoverConfiguration(forIssuer: urlComponents.url!.absoluteURL, completion: {configuration, error in
                    guard let config = configuration else {
                        print("Error retrieving discovery document: \(error?.localizedDescription ?? "Unknown")")
                        promiseSource.setResult(nil)
                        return
                    }

                    let tokenRequest: OIDTokenRequest = OIDTokenRequest(
                        configuration: config,
                        grantType: "http://tapkey.net/oauth/token_exchange",
                        authorizationCode: nil,
                        redirectURL: nil,
                        clientID: "wma-native-mobile-app",
                        clientSecret: nil,
                        scopes: [ "register:mobiles", "read:user", "handle:keys" ],
                        refreshToken: nil,
                        codeVerifier: nil,
                        additionalParameters: [
                            "provider": "wma.oauth",
                            "subject_token_type": "jwt",
                            "subject_token": idToken!,
                            "audience": "tapkey_api",
                            "requested_token_type": "access_token"
                        ]
                    )
                    
                    OIDAuthorizationService.perform(tokenRequest) { response, error in
                        if let tokenResponse = response {
                            if let accessToken = tokenResponse.accessToken {
                                promiseSource.setResult(accessToken)
                            } else {
                                print("error retrieving access_token")
                                promiseSource.setResult(nil)
                            }
                        } else {
                            print("error retrieving access_token")
                            promiseSource.setResult(nil)
                        }
                    }
                })
                
                return "unused"
            }.catchOnUi{(error) -> String in
                print(error)
                promiseSource.setResult(nil)
                return "unused"
            }.conclude()
        
        return promiseSource.promise
    }
}
