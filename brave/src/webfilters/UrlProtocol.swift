/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import CoreData

var requestCount = 0
let markerRequestHandled = "request-already-handled"

class URLProtocol: NSURLProtocol {

    var connection: NSURLConnection!
    var mutableData: NSMutableData!
    var response: NSURLResponse!

    static var suffixBlockedUrl = "_b_l_o_c_k_e_d_"

    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if (BraveApp.isBraveButtonBypassingFilters) {
            return false
        }

        //print("Request #\(requestCount++): URL = \(request.URL?.absoluteString)")
        if let scheme = request.URL?.scheme where !scheme.startsWith("http") {
            return false
        }

        if NSURLProtocol.propertyForKey(markerRequestHandled, inRequest: request) != nil {
            return false
        }

        #if !TEST
            delay(0) { // calls closure on main thread
                BraveApp.getCurrentWebView()?.setFlagToCheckIfLocationChanged()
            }
        #endif

        guard let url = request.URL else { return false }
        if (!TrackingProtection.singleton.shouldBlock(request) && !AdBlocker.singleton.shouldBlock(request) && HttpsEverywhere.singleton.tryRedirectingUrl(url) == nil) {
            return false
        }

        return true
    }

    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {

        if (TrackingProtection.singleton.shouldBlock(request) || AdBlocker.singleton.shouldBlock(request)) {
            let newRequest = cloneRequest(request)
            if let url = request.URL {
                // Note CFURLCopyScheme crash if the url value is nil or "" or modified host like: "https://blocked_\(host)\(path)
                // Just add a sentinel suffix, and returnEmptyResponse() if seen later
                newRequest.URL = NSURL(string:url.absoluteString + suffixBlockedUrl)
            }
            return newRequest
        }

        // TODO handle https redirect loop
        if let url = request.URL, redirectedUrl = HttpsEverywhere.singleton.tryRedirectingUrl(url) {
            let newRequest = cloneRequest(request)
            newRequest.URL = redirectedUrl
#if DEBUG
            print(url.absoluteString + " [HTTPE to] " + redirectedUrl.absoluteString)
#endif
            return newRequest
        }
        return request
    }

    private class func cloneRequest(request: NSURLRequest) -> NSMutableURLRequest {
        // Reportedly not safe to use built-in cloning methods: http://openradar.appspot.com/11596316
        let newRequest = NSMutableURLRequest(URL: request.URL!, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)
        newRequest.allHTTPHeaderFields = request.allHTTPHeaderFields
        if let m = request.HTTPMethod {
            newRequest.HTTPMethod = m
        }
        if let b = request.HTTPBodyStream {
            newRequest.HTTPBodyStream = b
        }
        if let b = request.HTTPBody {
            newRequest.HTTPBody = b
        }
        return newRequest
    }

    func returnEmptyResponse() {
        // To block the load nicely, return an empty result to the client.
        // Nice => UIWebView's isLoading property gets set to false
        // Not nice => isLoading stays true while page waits for blocked items that never arrive

        // IIRC expectedContentLength of 0 is buggy (can't find the reference now).
        guard let url = request.URL else { return }
        let response = NSURLResponse(URL: url, MIMEType: "text/html", expectedContentLength: 1, textEncodingName: "utf-8")
        client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
        client?.URLProtocol(self, didLoadData: NSData())
        client?.URLProtocolDidFinishLoading(self)
    }

    override func startLoading() {
        let newRequest = URLProtocol.cloneRequest(request)
        NSURLProtocol.setProperty(true, forKey: markerRequestHandled, inRequest: newRequest)
        self.connection = NSURLConnection(request: newRequest, delegate: self)

        if request.URL?.absoluteString.endsWith(URLProtocol.suffixBlockedUrl) ?? false {
            returnEmptyResponse()
        }
    }

    override func stopLoading() {
        if self.connection != nil {
            self.connection.cancel()
        }
        self.connection = nil
    }

    // MARK: NSURLConnection
    func connection(connection: NSURLConnection!, didReceiveResponse response: NSURLResponse!) {
        self.client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
        self.response = response
        self.mutableData = NSMutableData()
    }

    func connection(connection: NSURLConnection, willSendRequest request: NSURLRequest, redirectResponse response: NSURLResponse?) -> NSURLRequest?
    {
        if let response = response {
            client?.URLProtocol(self, wasRedirectedToRequest: request, redirectResponse: response)
        }
        return request
    }

    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        self.client!.URLProtocol(self, didLoadData: data)
        self.mutableData.appendData(data)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        self.client!.URLProtocolDidFinishLoading(self)
    }
    
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        self.client!.URLProtocol(self, didFailWithError: error)
    }
}
