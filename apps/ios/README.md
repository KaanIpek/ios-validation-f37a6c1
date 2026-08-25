# Grocery OS iOS internal beta

This directory contains the native iOS boundary for an internal TestFlight
candidate. It is not evidence that Apple accepted a build or that a build was
installed on a physical phone.

## Native value

- one persistent `WKWebView` session preserves the current Basket and retailer
  connection across native task navigation;
- a native bottom task bar provides Home, Plan, Basket, Shop, and Profile;
- a Share extension accepts a bounded public URL or creator-supplied text and
  writes one protected, one-time payload into a signed App Group;
- the app transfers that payload to `/import/social` in a URL fragment, so the
  creator caption does not enter ordinary HTTP request logs;
- non-Grocery-OS destinations open in the system browser, except for a bounded
  Kroger OAuth navigation chain;
- localhost, cleartext HTTP, raw IP, `.local`, user-info, query-bearing base
  URLs, and unexpanded release settings are rejected.

The first slice intentionally does not accept shared photos in the native Share
extension. The hosted app's reviewed image/screenshot picker remains available.

## Local generation on macOS

1. Install Xcode 16 or newer and XcodeGen 2.46.0.
2. Copy `Config/Shared.xcconfig` to an ignored release-specific file or provide
   its build settings from CI. Do not commit signing material. Distribution CI
   archives unsigned and asks Xcode to sign automatically at export using a
   protected App Store Connect API key; it does not export or transport a
   distribution P12 or provisioning profile.
3. Generate `GroceryOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` from
   the reviewed square brand source before archive.
4. Run `xcodegen generate --spec apps/ios/project.yml` from the repository root.
5. Build the `GroceryOS` scheme against an iOS 17+ simulator.

The authoritative release instructions and blockers are in
`docs/TESTFLIGHT_RELEASE_CANDIDATE_P3_103.md`.
