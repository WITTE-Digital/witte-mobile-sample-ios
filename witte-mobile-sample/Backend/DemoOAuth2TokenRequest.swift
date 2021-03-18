import Foundation
import TapkeyMobileLib

/**
 This class is for demonstration purpose only and should not be part of your production app.
 The corresponding functionality should be part of your backend implementation instead.
 */
class DemoOAuth2TokenRequest {
    /**
     Called to retrieve a flinkey API access token.

     - Parameters:
       - flinkeyApiKey: The flinkey-API-Key.
       - apiManagerUsername: The username of the API Manager.
       - apiManagerPassword: The password of the API Manager.
     - Returns: Promise to flinkey API access token (JWT).
     */
    func execute(withApiKey flinkeyApiKey: String,
                 andApiManagerUsername apiManagerUsername: String,
                 andApiManagerPassword apiManagerPassword: String) -> TKMPromise<String> {
        let promiseSource = TKMPromiseSource<String>()

        // prepare content
        let par1 = apiManagerUsername.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let par2 = apiManagerPassword.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let postBody = "username=\(par1)&password=\(par2)&grant_type=password"
        let postBodyBytes = Data(postBody.utf8)

        // create request
        let url = URL(string: "https://api.flinkey.de/v3/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = postBodyBytes
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(postBodyBytes.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("utf-8", forHTTPHeaderField: "charset")
        request.setValue(flinkeyApiKey, forHTTPHeaderField: "flinkey-API-Key")

        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) -> () in
            if nil != error {
                promiseSource.setError(error as! Error)
            } else if let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] {
                if let token = json["access_token"] as? String {
                    promiseSource.setResult(token)
                } else {
                    promiseSource.setError(TKMError(errorCode: "No property 'access_token' in JSON object."))
                }
            } else {
                promiseSource.setError(TKMError(errorCode: "Failed to create JSON object from response data"))
            }
        }
        task.resume()

        return promiseSource.promise
    }
}