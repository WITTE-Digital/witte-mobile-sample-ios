# witte-mobile-sample-ios

The WITTE mobile sample for iOS is a sample iOS project illustrating the basic steps to integrate the Tapkey SDK in conjunction with the WITTE backend in order to be able to trigger (open/close) a box.

## Features
* Authenticate with the Tapkey Mobile Library
* Query local keys
* Trigger (open/close) a box

## Getting Started

### Install CocoaPods dependencies
Dependencies are managed using CocoaPods. Before you can compile the sample app you need to run 'pod install' on the command line.
```
witte-mobile-sample-ios$ pod install
```

### Add your WITTE Customer ID, SDK Key and Subscription Key 

```swift
//
// AppDelegate.swift
//

// Your WITTE Customer Id.
// TODO: Add your WITTE Customer Id here.
private let _witteCustomerId: Int = -1;

// Your WITTE SDK Key.
// TODO: Add your WITTE SDK Key here.
private let _witteSdkKey: String = "Todo: Add your WITTE sdk key here"

// Your WITTE Subscription Key.
// TODO: Add your WITTE Subscription Key here.
private let _witteSubscriptionKey: String = "Todo: Add your WITTE subscription key here"
```

### Add a WITTE User ID
For the sake of simplicity this sample app uses a single user ID which is hard coded in the AppDelegate class. Before you can actually use this sample app to open and close flinkey boxes you need to create a user in the WITTE backend and assign the constant WitteUserId with your users ID.  

```swift
//
// AppDelegate.swift
//

// User Id of one specific WITTE user (this needs to be retrieved at runtime in production apps).
// TODO: Add your WITTE User Id here.
private let _witteUserId = -1
```

### Authentication
A user needs to be authenticated with the Tapkey backend via the Tapkey Mobile Library. This is achieved using a Java Web Token - the idToken - which is retrieved from the Witte backend. The idToken needs to be exchanged for an access token which is passed on to the Tapkey Mobile Library.

#### Retrieve access token
The access token is retrieved from the Tapkey backend by exchanging an idToken which needs to be retrieved from the WITTE backend for a specific user. 
1. Retrieve idToken from the Witte backen
2. Retrieve access token from the Tapkey backend by exchanging the idToken

The WITTE Mobile Library provides a class (IdTokenRequest) which can be used to query the idToken. For the token exchange we are using the [AppAuth for iOS](https://github.com/openid/AppAuth-iOS) library by OpenID. The example contains a class WitteTokenProvider that shows the whole process.

```swift
//
//  WitteTokenProvider.swift
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
```

#### Login to the Tapkey backend
The authentication with the Tapkey backend is done using the UserManager object which is part of the Tapkey Mobile Library. An access token is passed to UserManager's logInAsync method.
```swift
import TapkeyMobileLib

_witteTokenProvider.accessToken()
    .continueOnUi { (accesToken: String?) -> Void in
        
        // login to Tapkey backend
        self._tapkeyUserManager!.logInAsync(accessToken: accesToken!, cancellationToken: TKMCancellationTokens.None)
            .continueOnUi{ (userId: String?) -> Void in
                // login success
            }
            .catchOnUi{(error) -> Void in
                // login failed
            }
            .conclude();
    }
    .catchOnUi { (error: TKMAsyncError?) -> Void in
        print("Access token query failed. \(String(describing: error?.localizedDescription))")
    }
    .conclude()
```

#### Install an token refresh handler for re-authentication
In order to enable the Tapkey Mobile Library ot re-authenticate a user a custom token refresh handler needs to be implemented and registered. The class WitteTokenRefreshHandler is part of this sample.

```swift
//
//  WitteTokenProvider.swift
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
```

An instace of WitteTokenRefreshHandler is passed 
```swift
//
//  AppDelegate.swift
//

// register the WitteTokenRefreshHandler
_tapkeyServiceFactory = TKMServiceFactoryBuilder()
    .setConfig(config)
    .setTokenRefreshHandler(WitteTokenRefreshHandler(tokenProvider: _witteTokenProvider))
    .build()
```

### Query local keys
```swift
let userId = _tapkeyUserManager!.users[0]
_tapkeyKeyManager!.queryLocalKeysAsync(userId: userId, cancellationToken: TKMCancellationTokens.None)
        .continueOnUi { (keys: [TKMKeyDetails]?) -> Void in
            self._tapkeyKeys = keys ?? [];
        }
        .catchOnUi({ (error: TKMAsyncError) -> Void? in
            print("Query local keys failed.")
            return nil
        })
        .conclude()
```

### Trigger a box
```swift
_tapkeyBleLockScanner = tapkeyServiceFactory.bleLockScanner
_tapkeyBleLockCommunicator = tapkeyServiceFactory.bleLockCommunicator
_tapkeyCommandExecutionFacade = tapkeyServiceFactory.commandExecutionFacade

// ...

let bluetoothAddress = _tapkeyBleLockScanner!.getLock(physicalLockId: physicalLockId)?.bluetoothAddress
if(nil != bluetoothAddress) {
    _tapkeyBleLockCommunicator!
        .executeCommandAsync(
            bluetoothAddress: bluetoothAddress!,
            physicalLockId: physicalLockId,
            commandFunc: { tlcpConnection in self._tapkeyCommandExecutionFacade!.triggerLockAsync(tlcpConnection, cancellationToken: TKMCancellationTokens.None)},
            cancellationToken: TKMCancellationTokens.None)
        .continueOnUi{ (commandResult: TKMCommandResult?) -> Bool? in
            if commandResult?.code == TKMCommandResult.TKMCommandResultCode.ok {
                let responseData = commandResult?.responseData
                if(nil != responseData) {
                    let bytes = responseData! as! IOSByteArray
                    let data = bytes.toNSData()
                    let boxFeedback = WDBoxFeedback(responseData: data!)
                    
                    if(WDBoxState.unlocked == boxFeedback.boxState) {
                        print("Box has been opened")
                    }
                    else if(WDBoxState.locked == boxFeedback.boxState) {
                        print("Box has been closed")
                    }
                    else if(WDBoxState.drawerOpen == boxFeedback.boxState) {
                        print("The drawer of the Box is open")
                    }
                    
                    return true
                }
                else {
                    return false
                }
            }
            
            return false
        }
        .catchOnUi{ (error: TKMAsyncError) -> Bool? in
            print("triggerLock failed")
            return false
        }
        .conclude()
```