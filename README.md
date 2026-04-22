# Lifting Log

Native SwiftUI workout logging app for iPhone, built from a Claude design export and translated into reusable native components.

## Requirements

- Xcode 26+
- iOS Simulator runtime
- XcodeGen

## Commands

- `xcodegen generate`
- `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- `xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.3.1'`
