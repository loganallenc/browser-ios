/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import Alamofire

protocol NetworkDataFileLoaderDelegate: class {
    func fileLoader(_: NetworkDataFileLoader, setDataFile data: NSData?)
    func fileLoaderHasDataFile(_: NetworkDataFileLoader) -> Bool
}

class NetworkDataFileLoader {
    let dataUrl: NSURL
    let dataFile: String
    let nameOfDataDir: String

    weak var delegate: NetworkDataFileLoaderDelegate?

    init(url: NSURL, file: String, localDirName: String) {
        dataUrl = url
        dataFile = file
        nameOfDataDir = localDirName
    }

    // return the dir and a bool if the dir was created
    func createAndGetDataDirPath() -> (String, Bool) {
        if let dir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first {
            let path = dir + "/" + nameOfDataDir
            var wasCreated = false
            if !NSFileManager.defaultManager().fileExistsAtPath(path) {
                do {
                    try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    BraveApp.showErrorAlert(title: "Adblock error", error: "dataDir(): \(error)")
                }
                wasCreated = true
            }
            return (path, wasCreated)
        } else {
            BraveApp.showErrorAlert(title: "Adblock error", error: "Can't get documents dir.")
            return ("", false)
        }
    }

    func etagFileNameFromDataFile(dataFileName: String) -> String {
        return dataFileName + ".etag"
    }

    func readDataEtag() -> String? {
        let (dir, _) = createAndGetDataDirPath()
        let path = etagFileNameFromDataFile(dir + "/" + dataFile)
        if !NSFileManager.defaultManager().fileExistsAtPath(path) {
            return nil
        }
        guard let data = NSFileManager.defaultManager().contentsAtPath(path) else { return nil }
        return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
    }

    func writeData(data: NSData, etag: String?) {
        let (dir, wasCreated) = createAndGetDataDirPath()
        // If dir existed already, clear out the old one
        if !wasCreated {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(dir)
            } catch {
                print("writeData: \(error)")
            }
            createAndGetDataDirPath() // to re-create the directory
        }

        let path = dir + "/" + dataFile
        if !data.writeToFile(path, atomically: true) {
            BraveApp.showErrorAlert(title: "Adblock error", error: "Failed to write data to \(path)")
        }

        if let etagData = etag?.dataUsingEncoding(NSUTF8StringEncoding) {
            let etagPath = etagFileNameFromDataFile(path)
            if !etagData.writeToFile(etagPath, atomically: true) {
                BraveApp.showErrorAlert(title: "Adblock error", error: "Failed to write data to \(etagPath)")
            }
        }
    }

    func readData() -> NSData? {
        guard let path = pathToExistingDataOnDisk() else { return nil }
        return NSFileManager.defaultManager().contentsAtPath(path)
    }

    private func networkRequest(forceDownload force: Bool) {
        guard let delegate = delegate else { return }
        if !force && delegate.fileLoaderHasDataFile(self) {
            return
        }
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(dataUrl) {
            (data, response, error) -> Void in
            if let err = error {
                print(err.localizedDescription)
                delay(60) {
                    // keep trying every minute until successful
                    self.networkRequest(forceDownload: force)
                }
            }
            else {
                if let data = data, response = response as? NSHTTPURLResponse {
                    let etag = response.allHeaderFields["Etag"] as? String
                    self.writeData(data, etag: etag)
                    delegate.fileLoader(self, setDataFile: data)
                }
            }
        }
        task.resume()
    }

    func pathToExistingDataOnDisk() -> String? {
        let (dir, _) = createAndGetDataDirPath()
        let path = dir + "/" + dataFile
        return NSFileManager.defaultManager().fileExistsAtPath(path) ? path : nil
    }

    private func checkForUpdatedFileAfterDelay() {
        delay(5.0) { // a few seconds after startup, check to see if a new file is available
            Alamofire.request(.HEAD, self.dataUrl).response {
                request, response, data, error in
                if let err = error {
                    print("\(err)")
                } else {
                    guard let etag = response?.allHeaderFields["Etag"] as? String else { return }
                    let etagOnDisk = self.readDataEtag()
                    if etagOnDisk != etag {
                        self.networkRequest(forceDownload: true)
                    }
                }
            }
        }
    }

    func loadData() {
        let data = readData()
        if data == nil {
            networkRequest(forceDownload: false)
            return
        }

        delegate?.fileLoader(self, setDataFile: data)
        checkForUpdatedFileAfterDelay()
    }
}
