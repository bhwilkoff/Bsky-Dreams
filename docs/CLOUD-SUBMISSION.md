# Cloud submission runbook — Bsky Dreams (iOS)

How to ship Bsky Dreams to the **App Store**, built in the cloud. This is the current build/submit
PIPELINE truth — it supersedes the older `BskyDreams-iOS/docs/APP_STORE_GUIDE.md`, whose project
path + bundle id are STALE (it predates the current `app.bskydreams.ios` / spaced-path layout).

> **Why cloud:** the dev Mac runs a *beta* macOS, so a local archive is rejected by App Review
> (**ITMS-90301** — "built with this version of the OS"); Apple also keeps raising the Xcode floor
> (**ITMS-90111**). A GitHub-hosted **`macos-26`** runner (released macOS + Xcode 26.6) clears both,
> **free** for this public repo — the same pipeline Archive Watch uses, with no Xcode Cloud compute.

---

## App Store (iOS) — DEFAULT

1. **Bump the version + push.** Edit `BskyDreams-iOS/Bsky Dreams/AppVersion.xcconfig`
   (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` +1 — never via the Xcode identity panel),
   commit, push. The runner builds the committed version. (The Xcode Cloud build-number stamper
   `ci_scripts/ci_pre_xcodebuild.sh` is keyed to Xcode-Cloud env vars and is a no-op in GitHub Actions,
   so bump `CURRENT_PROJECT_VERSION` by hand before dispatching.)
2. **Run the workflow:**
   ```
   gh workflow run appstore-build.yml -f platform=ios
   gh run watch $(gh run list --workflow=appstore-build.yml -L1 --json databaseId -q '.[0].databaseId')
   ```
   `.github/workflows/appstore-build.yml` (runner `macos-26`) selects Xcode 26.6, imports the signing
   `.p12`s, and runs `tools/submit-appstore.sh ios` — which archives the **`Bsky Dreams`** scheme via
   the repo-root **`BskyDreams.xcworkspace`** (the project path has spaces + is two levels deep, so the
   tooling quotes it and builds the workspace), creates App Store profiles for **both** embedded bundle
   ids — `app.bskydreams.ios` and `app.bskydreams.ios.ShareExtension` — and uploads to App Store Connect.
3. **Submit for review — by API, no App Store Connect UI.** `tools/asc_release.py` (ported from
   UniversalAppTemplate) opens/renames the App Store version to `MARKETING_VERSION`, waits for the
   build to go VALID (10–30 min after upload), attaches it, sets What's New, and submits via the
   `reviewSubmissions` → `reviewSubmissionItems` → `submitted:true` flow. Pure REST, so it runs fine
   from the beta-OS dev Mac (needs PyJWT — `/usr/bin/python3` has it) or in the cloud:
   ```
   # local (team key already at ~/.appstoreconnect/private_keys; ids in Archive-Watch's env file)
   set -a; . ../Archive-Watch/tools/asc-credentials.env; set +a
   /usr/bin/python3 tools/asc_release.py status
   /usr/bin/python3 tools/asc_release.py ship --platform ios --notes-file whats-new.txt \
       --wait-build-minutes 40 --submit
   # or cloud (ubuntu runner)
   gh workflow run appstore-submit.yml -f mode=ship -f submit=true -f release_notes="…"
   ```
   Traps (all handled in the script): the obvious `appStoreVersionSubmissions` endpoint is deprecated
   and answers a misleading 403; an uploaded build does not create a version; attaching an
   unprocessed build fails with a confusing relationship error; Apple refuses review with no
   What's New. Export compliance is answered in Info.plist (`ITSAppUsesNonExemptEncryption = NO`).
   A failed build run may still have consumed its build number — bump before retrying.

**Signing** is MANUAL via `.p12` secrets (cloud signing fails for this team's API key). They're shared
across the team's apps (team `L2G756LY8N`) and already set: `APPLE_DIST_P12`, `APPLE_INSTALLER_P12`,
`APPLE_P12_PASSWORD`, `APPLE_DIST_CERT_ID`, `ASC_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID`. To re-seed:
`tools/ci_make_signing_p12.py distribution out.p12 <pw>` → `gh secret set APPLE_DIST_P12 …`.

Local `tools/submit-appstore.sh ios` works only on a released-macOS machine (ITMS-90301 on the beta box).

---

## Notes specific to this repo
- **iPhone-only** (the app target is `TARGETED_DEVICE_FAMILY = 1`); the archive still embeds the
  ShareExtension, so the export needs the extension's profile too — handled automatically by
  `asc_profiles.py` (it creates a profile per embedded bundle id discovered in the archive).
- **Manual Info.plists** (`GENERATE_INFOPLIST_FILE = NO`) for the app + ShareExtension; the version
  comes solely from `AppVersion.xcconfig` (wired as the base config of every target).
- No Android.
- The submission tooling (`tools/submit-appstore.sh`, `asc_certs.py`, `asc_profiles.py`,
  `ci_make_signing_p12.py`) is shared with Archive Watch — see its `apple-app-store-cli-submission`
  skill + `docs/macOS-DESIGN.md` §C for the deep details.
