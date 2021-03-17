import Foundation
import TapkeyMobileLib
import witte_mobile_library
import AppAuth

class TokenProvider {
    let backendAccessor: BackendAccessorProtocol

    init(withBackendAccessor backendAccessor: BackendAccessorProtocol) {
        self.backendAccessor = backendAccessor
    }

    /**
     Retrieves an access token to authenticate with the Tapkey Mobile Library.
     - Returns: Tapkey access token
     */
    func accessToken() -> TKMPromise<String> {
        let promiseSource = TKMPromiseSource<String>()

        backendAccessor.requestIdToken().continueOnUi { (idToken) -> Void in
            if ((idToken ?? "").isEmpty) {
                promiseSource.setError(TKMError(errorCode: "The flinkey idToken must not be null or empty"))
            } else {
                var urlComponents: URLComponents = URLComponents()
                urlComponents.scheme = "https"
                urlComponents.host = "login.tapkey.com"

                OIDAuthorizationService.discoverConfiguration(forIssuer: urlComponents.url!.absoluteURL, completion: { configuration, error in
                    guard let config = configuration else {
                        print("Error retrieving discovery document: \(error?.localizedDescription ?? "Unknown")")
                        promiseSource.setError(error as! Error)
                        return
                    }

                    let tokenRequest: OIDTokenRequest = OIDTokenRequest(
                            configuration: config,
                            grantType: "http://tapkey.net/oauth/token_exchange",
                            authorizationCode: nil,
                            redirectURL: nil,
                            clientID: "wma-native-mobile-app",
                            clientSecret: nil,
                            scopes: ["register:mobiles", "read:user", "handle:keys"],
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
                        if (nil != error) {
                            promiseSource.setError(error!)
                        } else if let tokenResponse = response {
                            if let accessToken = tokenResponse.accessToken {
                                promiseSource.setResult(accessToken)
                            } else {
                                promiseSource.setError(TKMError(errorCode: "error retrieving access_token"))
                            }
                        } else {
                            promiseSource.setError(TKMError(errorCode: "error retrieving access_token"))
                        }
                    }
                })
            }
        }.catchOnUi { (error) -> Void in
            promiseSource.setError(error)
        }.conclude()

        return promiseSource.promise
    }
}
