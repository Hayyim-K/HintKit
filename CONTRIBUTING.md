# Contributing to HintKit

Issues and pull requests are welcome.

## Development

Clone the repository and open `HintKit.xcodeproj` for framework development,
or `Examples/HintKitDemo/HintKitDemo.xcodeproj` to run the package-based demo.
The included projects require Xcode 16 or later. UIKit tests run on iOS
simulators; `swift test` on macOS is not a substitute for these tests.

## Before a pull request

- Run the HintKit scheme's tests on an installed iOS simulator.
- For UI changes, run the HintKitDemo UI test and inspect light/dark appearance.
- Keep the library's minimum iOS version at 15 unless a change is discussed.
- Verify both package and framework resource loading when changing the card.
- Write code comments in English and retain existing comments.
- Keep generated build files and personal Xcode state out of commits.

Example commands and the current test coverage are documented in the README.

## Reporting a bug

Include the Xcode version, iOS version, device or simulator, the relevant
HintOptions and HintStyle, and a minimal reproduction. For placement issues,
describe the host view hierarchy, scrolling, and safe-area behavior. Remove
personal information from screenshots and examples before posting them.
