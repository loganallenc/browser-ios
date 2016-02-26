# Brave iOS Browser 

Download in the [App Store](https://itunes.apple.com/app/brave-web-browser/id1052879175?mt=8)

Brave is based on Firefox iOS, most of the Brave-specific code is in the [brave dir](brave/)

These steps should be sufficient to build, but if you need more info, refer to the the [Firefox iOS readme](https://github.com/mozilla/firefox-ios/blob/master/README.md)

## Setup

Install [Node.js](https://nodejs.org/en/download/stable/) v5.0.0

Install Carthage 0.11 (not newer, due to https://github.com/Carthage/Carthage/issues/1124)
```
brew uninstall carthage # if you have it installed, removes so you can use an older version
brew install https://raw.githubusercontent.com/Homebrew/homebrew/09c09d73779d3854cd54206c41e38668cd4d2d0c/Library/Formula/carthage.rb
```

Do the following commands:
```
./checkout.sh
(cd brave && ./setup.sh)
open Client.xcodeproj
```

build Brave scheme

#### Note: building your own ad-hoc builds is supported [see user device build](brave/docs/USER-DEPLOYING.md)

## Updating Code 

After a git pull (i.e. updating from the remote) run

``` ./brave-proj.py ```

The Xcode project is generated, so local changes won't persist. And if files are added/removed after updating, your project won't be in sync unless the above command is run. 

## Crash reporting using Fabric

To enable, add ~/.brave-fabric-keys with 2 lines, the API key and build secret. Re-run ./brave-proj.py and the project will be generated to use Fabric and Crashlytics frameworks.

## Tests

Run Product>Test in Xcode to do so. Not all Firefox tests are passing yet.

## Contribution Notes

Most of the code is in the brave/ directory. The primary design goal has been to preserve easy merging from Firefox iOS upstream, so hopefully code changes outside of that dir are minimal.

To find changes outside of brave/, look for #if BRAVE / #if !BRAVE (#if/#else/#endif is supported by Swift).

## Provisioning Profiles using a Team account

(This section doesn't apply to individual developer accounts, Xcode managed profiles seem to work fine in that case.)

Do not use 'Xcode managed profiles', there is no advantage to this, and debugging problems with that system is a dead end due to lack of transparency in that system. 

```brave/build-system/profiles``` has some handy scripts to download the adhoc or developer profiles and install them.

## JS Tips

For anyone working with JS in iOS native, I recommend running and debugging your JS in an attached JS console. (Not using an edit/compile/debug cycle in Xcode). When you run from Xcode any iOS web view in the simulator (or attached device), you can then attach from Safari desktop (the Develop menu), and you get a JS console to work in. 

We have various JS interpreters available: UIWebView, JavaScriptCore, and WKWebView.

The first is required if we are running JS on the web page, since we are using UIWebView. JavaScriptCore is a stand-alone JS engine that I believe is more up-to-date than UIWebView's. WKWebView will have the most modern JS engine, but requires instantiating a WKWebView for this purpose, which we would prefer to avoid as that is a heavy approach. UIWebView's JS engine is a few years old, and is quite primitive.

None of these are comparable to Safari iOS's JS engine, which is highly up-to-date in its capabilities but is not available to us.

## Release Builds

```brave/build-system/build-archive.sh``` does everything. When that completes, the Fabric app detects a new archive and asks to distribute to testers.

## Misc Tips

Go to the Brave app folder for the most recently run simulator:
```
cd ~/Library/Developer/CoreSimulator/Devices && cd `ls -t | head -1` && cd data/Containers/Data/Application && cd `find . -iname "*brave*" | head -1 | xargs -I{} dirname {}`
```
