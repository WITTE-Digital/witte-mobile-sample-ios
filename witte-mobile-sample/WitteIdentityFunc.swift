//
//  WitteIdentityFunc.swift
//  witte-mobile-sample
//

import Foundation
import TapkeyMobileLib
import witte_mobile_library

class WitteIdentityFunc : NSObject, NetTpkyMcUtilsFunc {
    
    let configuration:WDConfiguration
    let userId:Int
    
    init(withConfiguration configuration:WDConfiguration, andUserId userId:Int) {
        self.configuration = configuration
        self.userId = userId
    }
    
    func invoke() -> Any! {
        let request = WDIdTokenRequest();
        let idToken = request.execute(with: configuration, andUserId: userId)
        let identity = NetTpkyMcModelIdentity(nsString: WD_IP_ID, with: idToken)
 
        return identity;
    }
}
