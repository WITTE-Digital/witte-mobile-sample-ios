import Foundation
import TapkeyMobileLib

/**
 This class is for demonstration purpose only and should not be part of your production app.
 The corresponding functionality should be part of your backend implementation instead.
 */
class DemoSdkTokenRequest {
    private let urlUAT: String = "https://api-uat.flinkey.de/v3/sdk/token"
    private let urlProd: String = "https://api.flinkey.de/v3/sdk/token"

    /**
     Called to retrieve a flinkey idToken.

     - Parameters:
       - flinkeyCustomerId: The flinkey Customer-ID.
       - flinkeyApiKey: The flinkey-API-Key.
       - flinkeySdkKey: The flinkey SDK Key.
       - flinkeyUserId: A flinkey user id.
       - flinkeyAccessToken: A flinkey API access token.
     - Returns: flinkey idToken (JWT)
     */
    func execute(withCustomerId flinkeyCustomerId: Int,
                 andApiKey flinkeyApiKey: String,
                 andSdkKey flinkeySdkKey: String,
                 andUserId flinkeyUserId: Int,
                 andAccessToken flinkeyAccessToken: String) -> TKMPromise<String> {
        let promiseSource = TKMPromiseSource<String>()

        // prepare content
        let postBody : [String : Any] = ["customerId" : flinkeyCustomerId, "userId" : flinkeyUserId, "sdkKey" : flinkeySdkKey]
        let postBodyBytes = try? JSONSerialization.data(withJSONObject: postBody, options: [])

        // create request
        let url = URL(string: urlUAT)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = postBodyBytes
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("utf-8", forHTTPHeaderField: "charset")
        request.setValue(flinkeyApiKey, forHTTPHeaderField: "flinkey-API-Key")
        request.setValue("Bearer \(flinkeyAccessToken)", forHTTPHeaderField: "Authorization")

        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) -> () in
            if nil != error {
                promiseSource.setError(error as! Error)
            } else if let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String : Any] {
                if let token = json["id_token"] as? String {
                    promiseSource.setResult(token)
                } else {
                    promiseSource.setError(TKMError(errorCode: "No property 'id_token' in JSON object."))
                }
            }
            else {
                promiseSource.setError(TKMError(errorCode: "Failed to create JSON object from response data"))
            }
        }
        task.resume()

        return promiseSource.promise
    }
}