# witte-mobile-sample-ios

The WITTE mobile sample for iOS is a sample iOS project illustrating the basic steps to integrate the Tapkey SDK in conjunction with the WITTE backend in order to be able to trigger (open/close) a box.

## Features
* Authenticate with the Tapkey Mobile Library
* Query local keys
* Trigger (open/close) a box

## Getting Started
### Authentication
A user needs to be authenticated with the Tapkey backend via the Tapkey Mobile Library. This is achived using a Java Web Token - the idToken - that is retrieved from the Tapkey backend and passed on to the Tapkey Mobile Library.

#### Retrieve idToken
The idToken is retrieved from the WITTE backend for a specific user. The WITTE Mobile Library provides a class (IdTokenRequest) that can be used to query the idToken.

```swift
import witte_mobile_library

let request = WDIdTokenRequest();
let idToken = request.execute(with: configuration, andUserId: userId)
```

#### Authenticate with the Tapkey backend
The authentication with the Tapkey backend is done using the UserManager object which is part of the Tapkey Mobile Library. A Identity object containing the idToken is passed to UserManager's authenticateAsync method.
```swift
import TapkeyMobileLib
import witte_mobile_library

Identity identity = new Identity(Configuration.IpId, idToken);
self._tapkeyUserManager!.authenticateAsync(identity: identity!, cancellationToken: TkCancellationToken_None)
        .continueOnUi({ (user: NetTpkyMcModelUser?) -> Void in
            
            // success
        })
        .catchOnUi({ (e: NSException?) -> Void in
            // authentication failed
        })
        .conclude();
```

#### Install an identity provider for re-authentication
In order to enable the Tapkey Mobile Library ot re-authenticate a user a custom identity provider needs to be implemented and registered. The class WitteIdentityProvider is part of this sample.

```swift
import Foundation
import TapkeyMobileLib
import witte_mobile_library

class WitteIdentityProvider: TkIdenitityProvider {

    let _witteConfiguration: WDConfiguration
    let _witteUserId: Int

    init(withConfiguration configuration: WDConfiguration, andUserId userId: Int) {
        _witteConfiguration = configuration
        _witteUserId = userId
    }

    func logOut(user: NetTpkyMcModelUser, cancellationToken: TkCancellationToken) -> TkPromise<Void> {
        return NetTpkyMcConcurrentAsync_PromiseFromResultWithId_(nil) as! TkPromise<Void>;
    }

    func refreshToken(user: NetTpkyMcModelUser, cancellationToken: TkCancellationToken) -> TkPromise<NetTpkyMcModelIdentity> {
        
        let identityFunc = WitteIdentityFunc(withConfiguration: _witteConfiguration, andUserId: _witteUserId);
        let concurrentPromise = NetTpkyMcConcurrentAsync.execute(with: identityFunc)
        let promise = concurrentPromise!.toTkPromiseWrapper() as TkPromise<NetTpkyMcModelIdentity>

        return promise
    }
}

// register the WITTE identity provider
_ = _tapkeyServiceFactory.getIdentityProviderRegistration().registerIdentityProvider(
        ipId: WD_IP_ID,
        identityProvider: _witteIdentityProvider)
```

### Query local keys
```swift
let user = _tapkeyUserManager!.getFirstUser()
_tapkeyKeyManager!.queryLocalKeysAsync(user: user!, forceUpdate: forceUpdate, cancellationToken: TkCancellationToken_None)
        .continueOnUi { (keys: [NetTpkyMcModelWebviewCachedKeyInformation]?) -> Void in
            self._tapkeyKeys = keys ?? [];
        }
        .catchOnUi { (e: NSException?) in
            NSLog("Query local keys failed. \(String(describing: e?.reason))");
        }
        .conclude();
```

### Trigger a box
```swift
_ = _tapkeyBleLockManager!.executeCommandAsync(deviceIds: [],physicalLockId: physicalLockId, commandFunc:
    { (tlcConnection: NetTpkyMcTlcpTlcpConnection?) -> TkPromise<NetTpkyMcModelCommandResult> in
        return self._tapkeyCommandExecutionFacade!.triggerLockAsync(tlcConnection, cancellationToken: TkCancellationToken_None)
    }, cancellationToken: TkCancellationToken_None)
    .continueOnUi({ (commandResult: NetTpkyMcModelCommandResult?) -> Bool in
        let code: NetTpkyMcModelCommandResult_CommandResultCode = commandResult?.getCode() ?? NetTpkyMcModelCommandResult_CommandResultCode.technicalError();
        switch(code) {
        case NetTpkyMcModelCommandResult_CommandResultCode.ok():
            let responseData = commandResult?.getResponseData()
            if(nil != responseData) {
                let bytes = responseData! as! IOSByteArray
                let data = bytes.toNSData()
                let boxFeedback = WDBoxFeedback(responseData: data!)
                
                if(WDBoxState.unlocked == boxFeedback.boxState) {
                    NSLog("Box has been opened")
                }
                else if(WDBoxState.locked == boxFeedback.boxState) {
                    NSLog("Box has been closed")
                }
                else if(WDBoxState.drawerOpen == boxFeedback.boxState) {
                    NSLog("The drawer of the Box is open")
                }
            }
            
            return true;
            
        default:
            return false;
        }
    })
    .catchOnUi({ (e:NSException?) -> Bool in
        NSLog("Trigger lock failed")
        return false;
    });
```