import { access, readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const requiredFiles = [
  "apps/ios/project.yml",
  "apps/ios/GroceryOS/GroceryOSApp.swift",
  "apps/ios/GroceryOS/GroceryOS.entitlements",
  "apps/ios/GroceryOS/Info.plist",
  "apps/ios/GroceryOS/PrivacyInfo.xcprivacy",
  "apps/ios/GroceryOSShare/ShareViewController.swift",
  "apps/ios/GroceryOSShare/GroceryOSShare.entitlements",
  "apps/ios/GroceryOSShare/Info.plist",
  "apps/ios/GroceryOSShare/PrivacyInfo.xcprivacy",
  "apps/ios/Shared/SharedRecipePayload.swift",
  "apps/ios/ExportOptions.plist.template",
  ".github/workflows/testflight.yml",
  "netlify.toml",
  "config/testflight-release-candidate.json",
];

const failures = [];
for (const path of requiredFiles) {
  try {
    await access(new URL(path, root));
  } catch {
    failures.push(`missing ${path}`);
  }
}

const [
  info,
  shareInfo,
  appEntitlements,
  shareEntitlements,
  project,
  exportOptions,
  workflow,
  exampleEnvironment,
  netlify,
  groceryWebView,
  rootView,
] = await Promise.all([
  readFile(new URL("apps/ios/GroceryOS/Info.plist", root), "utf8"),
  readFile(new URL("apps/ios/GroceryOSShare/Info.plist", root), "utf8"),
  readFile(new URL("apps/ios/GroceryOS/GroceryOS.entitlements", root), "utf8"),
  readFile(
    new URL("apps/ios/GroceryOSShare/GroceryOSShare.entitlements", root),
    "utf8",
  ),
  readFile(new URL("apps/ios/project.yml", root), "utf8"),
  readFile(new URL("apps/ios/ExportOptions.plist.template", root), "utf8"),
  readFile(new URL(".github/workflows/testflight.yml", root), "utf8"),
  readFile(new URL(".env.example", root), "utf8"),
  readFile(new URL("netlify.toml", root), "utf8"),
  readFile(new URL("apps/ios/GroceryOS/GroceryWebView.swift", root), "utf8"),
  readFile(new URL("apps/ios/GroceryOS/RootView.swift", root), "utf8"),
]);

if (!info.includes("NSAllowsArbitraryLoads</key><false/>"))
  failures.push("ATS is not fail-closed");
if (!info.includes("NSAllowsLocalNetworking</key><false/>"))
  failures.push("local networking is not disabled");
if (!info.includes("ITSAppUsesNonExemptEncryption</key>\n  <false/>"))
  failures.push("exempt-only encryption declaration is missing");
if (!shareInfo.includes("<key>NSExtension</key>"))
  failures.push("Share extension metadata is missing");
if (!shareInfo.includes("com.apple.share-services"))
  failures.push("Share extension point is missing");
for (const [name, entitlements] of [
  ["app", appEntitlements],
  ["share", shareEntitlements],
]) {
  if (!entitlements.includes("com.apple.security.application-groups"))
    failures.push(`${name} App Group entitlement is missing`);
}
if (!project.includes("minimumXcodeGenVersion: 2.46.0"))
  failures.push("XcodeGen version is not constrained");
for (const path of [
  "INFOPLIST_FILE: GroceryOS/Info.plist",
  "INFOPLIST_FILE: GroceryOSShare/Info.plist",
  "CODE_SIGN_ENTITLEMENTS: GroceryOS/GroceryOS.entitlements",
  "CODE_SIGN_ENTITLEMENTS: GroceryOSShare/GroceryOSShare.entitlements",
]) {
  if (!project.includes(path))
    failures.push(`Xcode project is missing ${path}`);
}
if (/^\s+(info|entitlements):\s*$/mu.test(project))
  failures.push("XcodeGen must not overwrite reviewed plist or entitlements");
if (!/^on:\s*\n\s*workflow_dispatch:/mu.test(workflow))
  failures.push("TestFlight workflow must be manual-only");
if (/\n\s*(push|pull_request|schedule):/u.test(workflow))
  failures.push("TestFlight workflow has an automatic trigger");
for (const phrase of [
  "upload-internal",
  "confirm_upload",
  "environment: testflight",
  "check-testflight-release-candidate.mjs",
  "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
  "actions/setup-node@249970729cb0ef3589644e2896645e5dc5ba9c38",
  "timeout-minutes: 8",
  "/Applications/Xcode_26.3.app/Contents/Developer",
  'xcrun simctl bootstatus "$simulator_id" -b',
  "-parallel-testing-enabled NO",
  "-maximum-parallel-testing-workers 1",
  "-project apps/ios/GroceryOS.xcodeproj",
  "CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO",
  "-allowProvisioningUpdates",
  "-authenticationKeyPath",
  "codesign -vvv --deep --strict",
  "embedded.mobileprovision",
]) {
  if (!workflow.includes(phrase))
    failures.push(`workflow is missing ${phrase}`);
}
if ((workflow.match(/test \"\$major\" -ge 26/g) ?? []).length !== 2)
  failures.push("both TestFlight jobs must fail closed below Xcode 26");
if (!info.includes("UIInterfaceOrientationPortraitUpsideDown"))
  failures.push("iPad multitasking requires upside-down portrait support");
for (const forbidden of [
  "IOS_DISTRIBUTION_P12_BASE64",
  "IOS_DISTRIBUTION_P12_PASSWORD",
  "IOS_APP_PROVISIONING_PROFILE_BASE64",
  "IOS_SHARE_PROVISIONING_PROFILE_BASE64",
  "TEMP_KEYCHAIN_PASSWORD",
]) {
  if (workflow.includes(forbidden) || exampleEnvironment.includes(forbidden))
    failures.push(`automatic-signing workflow must not require ${forbidden}`);
}
if (!project.includes("CODE_SIGN_STYLE: Automatic"))
  failures.push("Xcode project must use automatic signing");
if (project.includes("PROVISIONING_PROFILE_SPECIFIER"))
  failures.push("Xcode project must not pin manual provisioning profiles");
if (!exportOptions.includes("<key>testFlightInternalTestingOnly</key><true/>"))
  failures.push("export must be restricted to TestFlight internal testing");
if (!workflow.includes("Print :testFlightInternalTestingOnly"))
  failures.push("workflow must verify internal-only export configuration");
for (const flag of ["FEATURE_ORDER_SUBMIT=false", "FEATURE_AUTOBUY=false"]) {
  if (!exampleEnvironment.includes(flag))
    failures.push(`.env.example is missing ${flag}`);
}
for (const flag of [
  "FEATURE_ORDER_SUBMIT",
  "FEATURE_AUTOBUY",
  "FEATURE_PUBLIC_SCRAPING",
  "FEATURE_BROWSER_AUTOMATION",
  "FEATURE_COMMERCE_DEVELOPMENT_PROBE",
  "FEATURE_WIKIBOOKS_RECIPES",
  "FEATURE_SOCIAL_RECIPE_IMPORT",
  "FEATURE_TIKTOK_CAPTION_TRANSFORM",
  "FEATURE_HEALTH_PROFILE",
  "FEATURE_UGC_PUBLIC_SHARING",
  "FEATURE_LOCAL_PERSISTED_FIXTURE",
  "FEATURE_USDA_FDC",
  "FEATURE_OPENFDA_FOOD_ENFORCEMENT",
  "FEATURE_PUBLIC_STORE_DISCOVERY",
  "FEATURE_KROGER_PUBLIC_API",
  "FEATURE_KROGER_CART_OAUTH",
]) {
  if (!new RegExp(`^${flag} = "false"$`, "mu").test(netlify))
    failures.push(`Netlify staging must keep ${flag}=false`);
}
if (
  !groceryWebView.includes(
    "document.documentElement.dataset.nativeShell = 'ios'",
  )
)
  failures.push(
    "iOS web view must mark the native shell before document rendering",
  );
if (!groceryWebView.includes("injectionTime: .atDocumentStart"))
  failures.push("iOS native-shell marker must be injected at document start");
if (!rootView.includes('case retailerLinks = "Retailer links"'))
  failures.push("iOS menu must expose the bounded retailer-link destination");
if (!rootView.includes('case .shop: "/compare/kroger"'))
  failures.push("iOS Shop must remain isolated to the Kroger workflow");

process.stdout.write(
  `${JSON.stringify({ ready: failures.length === 0, failures }, null, 2)}\n`,
);
if (failures.length > 0) process.exitCode = 1;
