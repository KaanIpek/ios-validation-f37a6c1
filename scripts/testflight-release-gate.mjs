export const REQUIRED_PRE_UPLOAD_EVIDENCE = Object.freeze([
  "githubHttpsRemoteVerified",
  "githubAuthenticationVerified",
  "hostedHttpsWebOriginVerified",
  "ownerInternalBetaAuthorizationRecorded",
  "testFlightInternalOnlyConfigured",
  "appleDeveloperMembershipVerified",
  "appStoreConnectRecordVerified",
  "bundleIdentifiersRegistered",
  "appGroupRegistered",
  "appStoreConnectApiKeyVerified",
  "iosSimulatorAcceptancePassed",
]);

export const REQUIRED_EXTERNAL_RELEASE_EVIDENCE = Object.freeze([
  "privacyOwnerApprovalRecorded",
  "qualifiedCounselReviewRecorded",
]);

export const REQUIRED_POST_UPLOAD_ACCEPTANCE_EVIDENCE = Object.freeze([
  "distributionCertificateVerified",
  "provisioningProfilesVerified",
  "physicalIPhoneAcceptancePassed",
  "krogerOAuthOnIOSPassed",
  "shareExtensionOnIOSPassed",
]);

export const REQUIRED_SAFETY_FLAGS = Object.freeze([
  "FEATURE_ORDER_SUBMIT",
  "FEATURE_AUTOBUY",
  "FEATURE_PUBLIC_SCRAPING",
  "FEATURE_BROWSER_AUTOMATION",
]);

export function evaluateTestFlightCandidate(
  candidate,
  { postUpload = false } = {},
) {
  const blockers = [];
  if (candidate?.schemaVersion !== 1)
    blockers.push("unsupported schemaVersion");
  if (candidate?.releaseMode !== "OWNER_INTERNAL_TESTFLIGHT_ONLY") {
    blockers.push("releaseMode must remain OWNER_INTERNAL_TESTFLIGHT_ONLY");
  }
  if (candidate?.legalStatus !== "NOT_A_LEGAL_OPINION_REVIEW_REQUIRED") {
    blockers.push("legalStatus must not claim legal approval or certainty");
  }
  for (const flag of REQUIRED_SAFETY_FLAGS) {
    if (candidate?.safetyFlags?.[flag] !== false)
      blockers.push(`${flag} must be false`);
  }
  for (const field of REQUIRED_PRE_UPLOAD_EVIDENCE) {
    if (candidate?.evidence?.[field] !== true)
      blockers.push(`${field} is not verified`);
  }
  for (const field of REQUIRED_EXTERNAL_RELEASE_EVIDENCE) {
    if (candidate?.evidence?.[field] !== false)
      blockers.push(`${field} must remain false for an owner-only beta`);
  }
  if (postUpload) {
    for (const field of REQUIRED_POST_UPLOAD_ACCEPTANCE_EVIDENCE) {
      if (candidate?.evidence?.[field] !== true)
        blockers.push(`${field} is not verified`);
    }
    if (candidate?.evidence?.testFlightUploadConfirmed !== true) {
      blockers.push("testFlightUploadConfirmed is not verified");
    }
    if (
      typeof candidate?.evidence?.testFlightBuildIdentifier !== "string" ||
      candidate.evidence.testFlightBuildIdentifier.trim().length === 0
    ) {
      blockers.push("testFlightBuildIdentifier is missing");
    }
  }
  return { ready: blockers.length === 0, blockers };
}
