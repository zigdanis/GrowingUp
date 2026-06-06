# GrowingUp

iOS app for viewing current age in time components format.

Project built using MVP + Clean architecture patterns.

It has Unit Tests.

## Requirements

* Xcode 16 or newer (developed against Xcode 26 / iOS 26 SDK)
* iOS 12.0+ deployment target

## Building & Running

Dependencies are managed with Swift Package Manager and resolved
automatically by Xcode — no Carthage/CocoaPods step is needed.

```
git clone git@github.com:zigdanis/GrowingUp.git
cd GrowingUp
open GrowingUp.xcodeproj
```

Select the **GrowingUp** scheme and run on any iOS Simulator. Debug builds
use automatic ("Sign to Run Locally") code signing, so no provisioning
profile is required for the simulator.

From the command line:

```
xcodebuild -project GrowingUp.xcodeproj -scheme GrowingUp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Authors

* **Danis Ziganshin** - *Initial work* - [zigdanis](https://github.com/zigdanis)

## License

This project is not yet licensed