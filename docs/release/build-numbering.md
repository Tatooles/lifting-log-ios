# Build Numbering

Xcode Cloud owns TestFlight build numbers for LiftingLog.

The checked-in `CURRENT_PROJECT_VERSION` in `project.yml` and
`LiftingLog.xcodeproj/project.pbxproj` is only the local/manual archive default.
Do not open build-number-only pull requests just to match App Store Connect.

During Xcode Cloud builds, `ci_scripts/ci_pre_xcodebuild.sh` reads
`CI_BUILD_NUMBER` and writes it into the temporary CI checkout before Xcode
builds. The uploaded app bundle should therefore use the Xcode Cloud build
number even if the source value is older.

Manual archives are the exception. Before uploading manually from a local Mac,
set `CURRENT_PROJECT_VERSION` to the next available App Store Connect build
number, run `xcodegen generate`, and archive that result.
