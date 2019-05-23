//
//  WitteIdentityProvider.swift
//  witte-mobile-sample
//

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
