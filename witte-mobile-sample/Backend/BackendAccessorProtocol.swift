import Foundation
import TapkeyMobileLib

protocol BackendAccessorProtocol {
    /**
     Called to retrieve a flinkey idToken for the current user.

     - Returns: flinkey idToken (JWT)
     */
    func requestIdToken() -> TKMPromise<String>
}