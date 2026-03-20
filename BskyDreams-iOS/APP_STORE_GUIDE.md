# BskyDreams iOS — Build & App Store Submission Guide

## Prerequisites

Before you begin, you need:
- A **Mac** running macOS 15 (Sequoia) or later
- **Xcode 16+** (download from the Mac App Store or developer.apple.com)
- An **Apple Developer Program** membership ($99/year) — enroll at developer.apple.com/programs
- Your Bluesky **app password** (not your main password) for testing

---

## Part 1: Creating the Xcode Project

The source code lives in `BskyDreams-iOS/BskyDreams/`. You need to create an Xcode project that wraps it.

### Step 1: Open Xcode and create a new project

1. Launch Xcode
2. Choose **File → New → Project**
3. Select **iOS → App**
4. Fill in the form:
   - **Product Name:** `BskyDreams`
   - **Bundle Identifier:** `com.learningischange.bskydreams` *(or your own reverse-DNS identifier)*
   - **Team:** Select your Apple Developer account
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None (we use SwiftData manually)
5. Save the project **inside** the `BskyDreams-iOS/` folder

### Step 2: Replace the generated files

Xcode creates a default `ContentView.swift` and `BskyDreamsApp.swift`. Delete them (move to Trash), then add all the files from the `BskyDreams/` directory:

1. In Xcode's Project Navigator, right-click your target group
2. Choose **"Add Files to BskyDreams..."**
3. Select **all folders** from `BskyDreams-iOS/BskyDreams/`:
   - Auth/
   - Components/
   - Models/
   - Networking/
   - Store/
   - Utilities/
   - Views/ (and all subfolders)
   - `BskyDreamsApp.swift`
   - `ContentView.swift`
   - `Info.plist`
4. Check **"Create groups"** (not folder references)
5. Click **Add**

### Step 3: Configure the project

In Xcode, select your project in the Navigator, then click the target **BskyDreams**:

**General tab:**
- **Minimum Deployments:** iOS 17.0
- **Display Name:** Bsky Dreams
- Under **Frameworks, Libraries, and Embedded Content**: no additional frameworks needed (all are system)

**Signing & Capabilities tab:**
- Enable **Automatically manage signing**
- **Team:** Select **Learning is Change** (your company team, not your personal team — using the wrong team is the most common cause of bundle ID registration failures)
- The Bundle ID should be `com.learningischange.bskydreams`
- Click **+ Capability** and add:
  - `Background Modes` → check "Background fetch" and "Audio, AirPlay, and Picture in Picture"
  - `Push Notifications`
  - `App Groups` → add group `group.com.LearningIsChange.bskydreams`

> **Note on Keychain:** The app uses the iOS Keychain directly via the Security framework for storing credentials. This does *not* require the "Keychain Sharing" capability — that capability is only needed when sharing keychain items *between multiple apps*. Within a single app, Keychain access works without it.

**Info tab:**
- Verify the `Info.plist` keys are present (they're in the file you added)

### Step 4: Add fonts

The app uses **Syne** and **Inter** from Google Fonts.

1. Download from Google Fonts:
   - https://fonts.google.com/specimen/Syne → Download "Syne Bold" and "Syne ExtraBold"
   - https://fonts.google.com/specimen/Inter → Download the variable font
2. Drag the `.ttf` files into Xcode under a new group called `Resources/Fonts/`
3. In the Project Navigator, select each font file → in the Inspector on the right, check **Target Membership: BskyDreams**
4. Open `Info.plist` in Xcode's property list editor and add:
   - Key: `Fonts provided by application` (UIAppFonts)
   - Type: Array
   - Add string entries for each font filename, e.g. `Syne-Bold.ttf`, `Inter-Variable.ttf`

### Step 5: Build and test locally

1. Select your iPhone from the device picker (or choose an iPhone simulator)
2. Press **⌘R** to build and run
3. The app should launch and show the login screen
4. Log in with your Bluesky handle and an app password

**Common first-build issues:**
- *"Cannot find type 'ComposeView'"* — Make sure all Swift files are added to the target
- *"Module 'Charts' not found"* — Charts is a system framework; select your target → Build Phases → Link Binary with Libraries → add `Charts.framework`
- Font errors — Double-check font filenames in Info.plist exactly match the `.ttf` filenames

---

## Part 2: Testing on a Real Device

### Step 1: Register your device

1. Connect your iPhone via USB
2. Trust the computer on your phone when prompted
3. In Xcode, select your iPhone from the device picker at the top
4. Xcode will automatically register the device with your Apple Developer account

### Step 2: Run on device

Press **⌘R**. The first time, you'll need to trust the developer certificate on your iPhone:
- **Settings → General → VPN & Device Management → [Your Name] → Trust**

### Step 3: Test all features

Before submitting, thoroughly test:
- [ ] Login / logout
- [ ] Home feed (Following + Discover)
- [ ] Infinite scroll and pull-to-refresh
- [ ] Compose post with text
- [ ] Compose post with images (test photo library access permission)
- [ ] Compose post with video (upload + background processing)
- [ ] Reply to a post
- [ ] Like and repost (optimistic UI)
- [ ] Thread view (nested replies)
- [ ] Profile view (follow/unfollow)
- [ ] Search (posts + people)
- [ ] Notifications
- [ ] Direct messages (send + receive via polling)
- [ ] Gallery view
- [ ] TV mode (video playback)
- [ ] Reader view (article loading)
- [ ] Analytics charts
- [ ] Constellation network graph
- [ ] Share Extension (share image/video from Photos)
- [ ] Background → foreground token refresh

---

## Part 3: Registering Your Bundle ID and App IDs

> **This is the step most people get stuck on.** App Store Connect's "Bundle ID" dropdown only shows IDs that have already been registered in the Apple Developer portal under the **correct team**. You must register them there first, before creating the app in App Store Connect.
>
> **Critical:** Make sure you are signed in under your **Learning is Change** company team everywhere — in Xcode, in the Developer portal, and in App Store Connect. Using your personal team causes bundle ID conflicts because personal team IDs are in a separate namespace.

### Step 1: Register the main App ID

1. Go to **developer.apple.com** (not App Store Connect — this is a different site)
2. Sign in and confirm the team selector in the top-right shows **Learning is Change** (not your personal name)
3. Click **Certificates, Identifiers & Profiles** in the left column
4. Under **Identifiers**, click the **+** button
5. Select **App IDs** → Continue
6. Select **App** → Continue
7. Fill in:
   - **Description:** `Bsky Dreams`
   - **Bundle ID:** Select **Explicit** and enter `com.learningischange.bskydreams`
     *(Use exactly this value, matching your Xcode project)*
8. Scroll down to **Capabilities** and enable:
   - ✅ App Groups
   - ✅ Background Modes
   - ✅ Push Notifications
   *(Keychain Sharing is not required — the app uses the standard Keychain API, not cross-app keychain sharing)*
9. Click **Continue** → **Register**

### Step 2: Register the Share Extension App ID

The Share Extension is a separate binary and needs its own App ID.

1. Click **+** again in Identifiers
2. Select **App IDs** → App → Continue
3. Fill in:
   - **Description:** `Bsky Dreams Share Extension`
   - **Bundle ID:** `com.learningischange.bskydreams.ShareExtension`
4. Enable capabilities:
   - ✅ App Groups
5. Click **Continue** → **Register**

### Step 3: Register the App Group

App Groups must be explicitly registered before they can be used.

1. Click **+** in Identifiers
2. Select **App Groups** → Continue
3. Enter:
   - **Description:** `Bsky Dreams App Group`
   - **Identifier:** `group.com.LearningIsChange.bskydreams`
4. Click **Continue** → **Register**

### Step 4: Assign the App Group to both App IDs

1. In Identifiers, click on `com.learningischange.bskydreams`
2. Under Capabilities, find **App Groups** → click **Configure**
3. Check the box next to `group.com.LearningIsChange.bskydreams`
4. Click **Continue** → **Save**
5. Repeat for `com.learningischange.bskydreams.ShareExtension`

### Step 5: Create the App Store Connect record

Now that the App ID is registered, it will appear in App Store Connect's dropdown:

1. Go to **appstoreconnect.apple.com**
2. Click **My Apps → +** → **New App**
3. Fill in:
   - **Platform:** iOS
   - **Name:** Bsky Dreams
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** Select `com.learningischange.bskydreams` from the dropdown
     *(If it still doesn't appear: wait 5 minutes and refresh. If it's missing, the App ID may not have been saved correctly — go back and verify in the Developer portal.)*
   - **SKU:** `bskydreams-001` (any unique alphanumeric string)
   - **User Access:** Full Access
4. Click **Create**

### Troubleshooting: Bundle ID not appearing in dropdown

| Problem | Fix |
|---------|-----|
| Dropdown shows "No bundle IDs" | You haven't registered it yet — complete Steps 1–2 above |
| Bundle ID listed but grayed out | It's already in use by another app on your account |
| Bundle ID registered but still missing | Wait 10 minutes; Apple's portal sync is slow. Try a hard refresh (⌘⇧R) |
| "An App ID with Identifier ... is not available" | Either already taken by another developer, or you're signed into the **wrong team** — confirm the top-right dropdown on developer.apple.com shows **Learning is Change**, not your personal account |
| Registered fine on developer.apple.com but still missing in App Store Connect | App Store Connect also has a team switcher in the top-right — make sure it shows **Learning is Change** before creating the app |
| Xcode signing shows a red error after adding capabilities | Xcode needs to refresh the provisioning profile — click "Try Again" or re-enable "Automatically manage signing" |

### Step 6: App information

In your App Store Connect record:

**App Information:**
- Category: Social Networking
- Secondary Category: News (optional)
- Content Rights: Check "does not contain third-party content"
- Age Rating: Click "Edit" → answer all questions (no mature content; Bluesky has content filtering, so adult content flags are minimal)

**Pricing:**
- Set to **Free**

**App Privacy:**

| Data Type | Collected? | Linked to Identity | Used for Tracking |
|-----------|-----------|-------------------|-------------------|
| Name | Yes | Yes | No |
| Username | Yes | Yes | No |
| Email Address | No | — | — |
| Photos or Videos | Yes | No | No |
| User Content (Messages) | Yes | Yes | No |
| Other User Content (posts) | Yes | Yes | No |

Data Use: "App Functionality" for all. No tracking.

---

## Part 4: Automated Screenshots

Taking screenshots manually across multiple simulators is tedious. Here's how to automate it using Xcode's built-in UI testing — no third-party tools required.

### Approach: Xcode UI Test + Screenshot Attachments

This creates a UI test target that navigates through the app and captures screenshots. You run it once; screenshots are saved inside Xcode's test result bundle and can be exported.

### Step 1: Add a UI Test target

1. In Xcode, go to **File → New → Target**
2. Select **UI Testing Bundle**
3. Name it `BskyDreamsScreenshots`
4. Make sure it targets the `BskyDreams` app
5. Click **Finish**

### Step 2: Create the screenshot test file

Replace the generated test file content with this. Save login credentials as environment variables (never hardcode them):

**`BskyDreamsScreenshots/ScreenshotTests.swift`:**

```swift
import XCTest

final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pass test credentials via scheme environment variables (see Step 4)
        app.launchEnvironment["SCREENSHOT_HANDLE"] =
            ProcessInfo.processInfo.environment["SCREENSHOT_HANDLE"] ?? ""
        app.launchEnvironment["SCREENSHOT_PASSWORD"] =
            ProcessInfo.processInfo.environment["SCREENSHOT_PASSWORD"] ?? ""
        app.launch()
    }

    func testCaptureAllScreenshots() throws {
        // --- Login ---
        let handleField = app.textFields["handle.bsky.social"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 10))
        handleField.tap()
        handleField.typeText(app.launchEnvironment["SCREENSHOT_HANDLE"] ?? "")

        let passwordField = app.secureTextFields.firstMatch
        passwordField.tap()
        passwordField.typeText(app.launchEnvironment["SCREENSHOT_PASSWORD"] ?? "")

        app.buttons["SIGN IN"].tap()

        // Wait for feed to load
        let feedCell = app.scrollViews.firstMatch
        XCTAssertTrue(feedCell.waitForExistence(timeout: 30))
        sleep(2)  // let images load

        // --- Screenshot 1: Home feed ---
        saveScreenshot(named: "01_home_feed")

        // --- Screenshot 2: Search ---
        app.buttons["Search"].tap()
        sleep(1)
        saveScreenshot(named: "02_search")

        // --- Screenshot 3: Notifications ---
        app.buttons["Notifications"].tap()
        sleep(2)
        saveScreenshot(named: "03_notifications")

        // --- Screenshot 4: Gallery ---
        app.buttons["Gallery"].tap()
        sleep(2)
        saveScreenshot(named: "04_gallery")

        // --- Screenshot 5: Constellation ---
        app.buttons["Constellation"].tap()
        sleep(1)
        saveScreenshot(named: "05_constellation")
    }

    private func saveScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### Step 3: Export screenshots after running

1. Run the test: **Product → Test** (or ⌘U) with an iPhone 16 Pro Max simulator selected
2. After tests complete, click the **Report Navigator** (the speech-bubble icon in the left panel)
3. Click the latest test run
4. Find `testCaptureAllScreenshots` → expand it → click any screenshot attachment
5. Right-click → **Export** to save as PNG
6. Repeat for each simulator size required

### Step 4: Set up environment variables for credentials

Never hardcode credentials in the test file. Instead:

1. In Xcode, click the scheme picker → **Edit Scheme**
2. Select **Test** in the left column
3. Click **Arguments** tab
4. Under **Environment Variables**, add:
   - `SCREENSHOT_HANDLE` = your Bluesky handle (e.g. `yourname.bsky.social`)
   - `SCREENSHOT_PASSWORD` = your app password
5. These are local to your machine and not committed to git

### Step 5: Run for each required simulator

App Store requires screenshots from specific device sizes. Run the test on each:

| Simulator | Required | Size |
|-----------|----------|------|
| iPhone 16 Pro Max | ✅ Yes | 1320×2868 |
| iPhone 15 Plus or 14 Plus | ✅ Yes (for older 6.7") | 1290×2796 |
| iPad Pro 13" M4 | Only if targeting iPad | 2064×2752 |

To switch simulators: change the destination in the scheme before running tests.

### Automating screenshot export via shell script

Once you've run the tests, this script extracts all PNG attachments from the latest test result:

```bash
#!/bin/bash
# export_screenshots.sh — run from your project root after UI tests complete

RESULTS_DIR=$(find ~/Library/Developer/Xcode/TestResults -name "*.xcresult" \
    -newer /tmp/last_screenshot_export 2>/dev/null | sort -r | head -1)

if [ -z "$RESULTS_DIR" ]; then
    echo "No test results found. Run UI tests first."
    exit 1
fi

OUTPUT_DIR="./Screenshots"
mkdir -p "$OUTPUT_DIR"

xcrun xcresulttool export --path "$RESULTS_DIR" \
    --output-path "$OUTPUT_DIR" \
    --type directory 2>/dev/null

echo "Screenshots exported to $OUTPUT_DIR"
touch /tmp/last_screenshot_export
```

Run with: `bash export_screenshots.sh`

### App Store description and metadata

**App Description (copy-paste ready):**
```
Bsky Dreams is a powerful Bluesky client designed for people who want to
get more out of the AT Protocol social network.

FEATURES
• Smart home feed with Following and Discover tabs
• Advanced search with filters (date, author, language)
• Saved search channels — curate your information streams
• Threaded conversations with depth-coded visual nesting
• Network Constellation — interactive force graph of who's talking to whom
• TV Mode — vertical video feed with topic selector
• Gallery — pure image browsing with lightbox viewer
• Reader View — distraction-free article reading built in
• Direct Messages with real-time polling
• Compose with images, video, GIFs, link previews, and @mention autocomplete
• Share Extension — share anything from Photos or Safari directly to Bsky Dreams
• Background notifications with push badge support

PRIVACY
Your app password is stored only in your device's secure Keychain — never
transmitted to any server other than bsky.social. All API calls go directly
to the Bluesky AT Protocol. No tracking. No analytics. No ads.

Requires a free Bluesky account. Generate an App Password at:
bsky.app → Settings → App Passwords
```

**Keywords** (100 chars max):
`bluesky,atproto,social,fediverse,decentralized,feed,thread,network,posts,timeline`

**Promotional Text** (170 chars max, can be updated without a new review):
`The most powerful Bluesky client for iPhone. Advanced search, video feed, network visualization, and full AT Protocol support.`

**Support URL:** `https://github.com/bhwilkoff/Bsky-Dreams/issues` (or bskydreams.com)

---

## Part 5: Build Settings for Release

In Xcode:

1. Change the scheme to Release:
   - Click the scheme picker → **Edit Scheme → Run → Build Configuration → Release**

2. Set the version:
   - Project Navigator → BskyDreams target → General
   - **Version:** 1.0
   - **Build:** 1

3. Choose **"Any iOS Device (arm64)"** from the device picker (not a simulator)

4. Verify your app icon:
   - Assets.xcassets → AppIcon → must have a 1024×1024 PNG in the App Store slot
   - No alpha channel, no transparency — Apple rejects icons with alpha

---

## Part 6: Archiving and Uploading

### Step 1: Archive the app

1. **Product → Archive** (Xcode menu bar)
2. Wait for the build — typically 2–5 minutes
3. The **Organizer** window opens automatically showing your archive

### Step 2: Validate before uploading

1. In Organizer, select the archive
2. Click **Validate App**
3. Choose **"Automatically manage signing"** → Next
4. Click **Validate**
5. Fix any issues before proceeding

**Common validation failures:**

| Error | Fix |
|-------|-----|
| "Missing push notification entitlement" | Ensure Push Notifications capability is enabled in your App ID (Step 3.1 above) and in Xcode's Signing & Capabilities |
| "App icon is missing or has wrong dimensions" | Add a 1024×1024 PNG to AppIcon in Assets.xcassets |
| "Invalid Bundle — missing required PrivacyInfo.xcprivacy" | Add the privacy manifest (see below) |
| "Provisioning profile doesn't include capability" | Re-register the App ID with the capability, then let Xcode re-download the provisioning profile |
| "The app references non-public selectors" | Remove any use of private APIs |

### Step 3: Upload to App Store Connect

1. In Organizer, click **Distribute App**
2. Choose **App Store Connect** → **Upload** → Next
3. Leave all checkboxes at their defaults (strip Swift symbols, include bitcode if offered)
4. Choose **Automatically manage signing** → Next
5. Review the summary → click **Upload**
6. Upload takes 1–10 minutes

### Step 4: Wait for processing and add to TestFlight

1. In App Store Connect → your app → **TestFlight** tab
2. The build appears as "Processing" — wait 5–30 minutes
3. You'll receive an email when it's ready
4. Click the build → **Enable TestFlight Public Link** or add yourself as an internal tester
5. Install via the TestFlight app and do a final smoke test on a real device

---

## Part 7: App Store Connect — Complete Field Reference

App Store Connect is organized into several independent sections. Each is covered below with every field, what it means, and what to enter for Bsky Dreams. Work through them in order.

---

### Section A: App Information

Found in the left sidebar under your app name. These fields apply to the app permanently, not per-version.

#### A1 — Name
- **What it is:** The name displayed on the App Store listing and under the icon on device. 30 character max.
- **Enter:** `Bsky Dreams`
- **Note:** If "Bsky Dreams" is taken (App Store names must be unique globally), try "Bsky Dreams: Bluesky Client".

#### A2 — Subtitle
- **What it is:** A short tagline shown below the app name in search results. 30 character max. Optional but strongly recommended — it appears in search and boosts discoverability.
- **Enter:** `The Advanced Bluesky Client`
- **Note:** Cannot repeat words from the Name. Updates to subtitle require a new app review.

#### A3 — Privacy Policy URL
- **What it is:** A required link to a publicly accessible privacy policy page. Apple will reject without it.
- **Enter:** Your privacy policy URL. If you don't have a hosted page yet, create a simple one at GitHub Pages or use a free service like Termly or PrivacyPolicyGenerator.io. Minimum content: what data is collected, where it goes, how users can delete it.
- **Suggested content for Bsky Dreams:** "Bsky Dreams stores your Bluesky app password in your device's Keychain. No data is transmitted to any server other than bsky.social. We do not collect analytics, crash reports, or personal information. To delete your data, log out of the app and uninstall it."

#### A4 — Primary Category
- **What it is:** The main category your app appears under in the App Store.
- **Enter:** `Social Networking`

#### A5 — Secondary Category
- **What it is:** An optional second category. Helps discoverability. Optional.
- **Enter:** `News` (since the Reader view is a core feature)

#### A6 — Content Rights
- **What it is:** A declaration of whether your app contains third-party copyrighted material.
- **Enter:** Check **"This app does not contain, show, or access third-party content."**
- **Note:** Bsky Dreams displays user-generated content from Bluesky but doesn't embed licensed third-party media (music, video libraries, etc.), so this is accurate.

#### A7 — Age Rating
- **What it is:** Apple's content rating system. Clicking "Edit" opens a questionnaire. Your answers determine the rating automatically — you cannot set it manually.
- **Answer the questionnaire as follows:**

| Question | Answer | Reason |
|----------|--------|--------|
| Cartoon or Fantasy Violence | None | No violence |
| Realistic Violence | None | No violence |
| Prolonged Graphic or Sadistic Realistic Violence | None | No violence |
| Profanity or Crude Humor | None | App doesn't generate content |
| Mature/Suggestive Themes | Infrequent/Mild | Users may post suggestive content on Bluesky |
| Horror/Fear Themes | None | |
| Medical/Treatment Information | None | |
| Alcohol, Tobacco, or Drug Use | None | |
| Simulated Gambling | None | |
| Sexual Content or Nudity | Infrequent/Mild | Bluesky has adult content toggle; app inherits it |
| Graphic Sexual Content and Nudity | None | App has adult content filter |
| Unrestricted Web Access | No | App only connects to bsky.social |
| Gambling and Contests | No | |
| **User-Generated Content** | **YES** | Users create and view posts, DMs, replies |

- **Expected result:** Rating of **12+** (due to user-generated content and possible mild suggestive material)
- **Note on UGC:** Because you checked User-Generated Content, Apple will ask follow-up questions. Answer: the app has a report mechanism (the "..." menu on posts → Report), and Bluesky provides moderation at the platform level.

#### A8 — License Agreement
- **What it is:** You can optionally attach a custom End User License Agreement (EULA). If you leave this blank, Apple's standard Terms of Service applies.
- **Enter:** Leave blank unless you have a specific EULA. The standard Apple terms are sufficient.

---

### Section B: Pricing and Availability

Found in the left sidebar. Set this before submitting.

#### B1 — Price
- **What it is:** Your app's price tier. Free apps have no tier selection.
- **Enter:** Select **Free** (Price: $0.00)
- **Note:** You cannot change from paid to free or vice versa after your app has had purchases. Starting free is the right call for a v1.

#### B2 — Availability
- **What it is:** Which countries and regions your app is available in.
- **Enter:** Leave at the default **"Available in all territories"** unless you have a specific reason to restrict.
- **Note:** You can always remove territories later but you cannot retroactively grant access to users in regions where the app wasn't available.

#### B3 — Pre-Order
- **What it is:** Lets users "order" the app before it's released. It auto-downloads on release day.
- **Enter:** Leave **off**. Pre-order is for apps where you want to build a waitlist before launch. Not applicable for a standard first submission.

#### B4 — Educational Discount
- **What it is:** Opt in to Apple's Volume Purchase Program for educational institutions.
- **Enter:** Leave as-is (only relevant for paid apps).

---

### Section C: App Privacy

Found in the left sidebar. This section generates the "Privacy Nutrition Label" shown on your App Store listing. It is one of the most scrutinized sections — be accurate.

#### C1 — Privacy Policy URL
- Same URL as A3. Enter it here again.

#### C2 — Data Collection Questionnaire

Click **"Get Started"** to enter the questionnaire. For each data type Apple lists, you declare whether you collect it, what you use it for, whether it's linked to identity, and whether it's used for tracking.

**For Bsky Dreams, answer as follows:**

**Contact Info:**
| Sub-type | Collected | Linked to Identity | Tracking | Purpose |
|----------|-----------|-------------------|----------|---------|
| Name | Yes | Yes | No | App Functionality |
| Email Address | No | — | — | — |
| Phone Number | No | — | — | — |
| Physical Address | No | — | — | — |
| Other User Contact Info | No | — | — | — |

*Why Name=Yes: The user's Bluesky display name is shown throughout the app.*

**Health & Fitness:** All No.

**Financial Info:** All No.

**Location:**
| Sub-type | Collected |
|----------|-----------|
| Precise Location | No |
| Coarse Location | No |

**Sensitive Info:** All No.

**Contacts:** No (app does not access the device contacts book).

**User Content:**
| Sub-type | Collected | Linked to Identity | Tracking | Purpose |
|----------|-----------|-------------------|----------|---------|
| Emails or Text Messages | No | — | — | — |
| Photos or Videos | Yes | No | No | App Functionality |
| Audio Data | No | — | — | — |
| Gameplay Content | No | — | — | — |
| Customer Support | No | — | — | — |
| Other User Content | Yes | Yes | No | App Functionality |

*Why Photos=Yes: Users select and upload photos from their library.*
*Why Other User Content=Yes: Users create posts and DMs.*

**Browsing History:** No.

**Search History:**
| Sub-type | Collected | Linked to Identity | Tracking | Purpose |
|----------|-----------|-------------------|----------|---------|
| Search History | No | — | — | — |

*Note: Search queries are sent to bsky.social but not stored by the app itself.*

**Identifiers:**
| Sub-type | Collected | Linked to Identity | Tracking | Purpose |
|----------|-----------|-------------------|----------|---------|
| User ID | Yes | Yes | No | App Functionality |
| Device ID | No | — | — | — |

*Why User ID=Yes: The user's Bluesky DID (decentralized identifier) is used throughout the app.*

**Purchases:** No.

**Usage Data:**
| Sub-type | Collected |
|----------|-----------|
| Product Interaction | No |
| Advertising Data | No |
| Other Usage Data | No |

**Diagnostics:**
| Sub-type | Collected |
|----------|-----------|
| Crash Data | No |
| Performance Data | No |
| Other Diagnostic Data | No |

**Tracking:**
- **Do you or your third-party partners use data collected from this app to track users?** → **No**

---

### Section D: Version Information (Prepare for Submission)

Go to **iOS App → 1.0 Prepare for Submission** in the left sidebar. This is the main submission form.

#### D1 — App Previews and Screenshots

**What it is:** Images and optional videos shown on your App Store listing. This is the most important marketing asset — most users decide to download based on screenshots.

**Required device sizes (you must upload at least one):**
- **6.9" Display (iPhone 16 Pro Max)** — 1320×2868 pixels — **REQUIRED**
- **6.7" Display (iPhone 14 Plus / 15 Plus)** — 1290×2796 pixels — Required for older devices to display correctly

**Optional but recommended:**
- **5.5" Display (iPhone 8 Plus)** — 1242×2208 pixels — If you skip 6.7" and 6.9" both show the same set

**iPad (only if you support iPad):** Skip for now — the app targets iPhone only.

**App Previews (video):** Optional. 15–30 second MP4 or MOV showing the app in use. Plays automatically in search results. Max 500 MB. Highly effective but time-consuming to produce — skip for v1.

**Screenshot guidelines:**
- Up to 10 screenshots per device size
- Shown in the order you upload them — put your best one first
- Can include caption text overlaid on screenshots (done externally in a tool like Sketch, Figma, or Canva before uploading — App Store Connect doesn't add text for you)
- Must show actual app UI — no marketing mockups that misrepresent the app
- No device frames required (but they look more professional)

**Recommended 5 screenshots for Bsky Dreams:**
1. Home feed with several posts visible (shows the neubrutalist design immediately)
2. Network Constellation (unique feature — differentiates from other Bluesky clients)
3. TV Mode with a video playing
4. Gallery view (image browsing)
5. Compose sheet or Thread view

#### D2 — Promotional Text
- **What it is:** Up to 170 characters shown above the description. **Can be updated at any time without a new app review.** Use this for timely messaging ("Now with video support!", "Version 1.2 just released").
- **Enter:** `The most powerful Bluesky client for iPhone. Advanced search, video feed, network visualization, and full AT Protocol support.`

#### D3 — Description
- **What it is:** Up to 4000 characters. Shown on the listing page under "more". The first 3 lines are visible before the user taps "more" — make them count.
- **Enter:**
```
Bsky Dreams is a powerful Bluesky client designed for people who want to
get more out of the AT Protocol social network.

FEATURES
• Smart home feed with Following and Discover tabs
• Advanced search with filters (date, author, language)
• Saved search channels — curate your information streams
• Threaded conversations with depth-coded visual nesting
• Network Constellation — interactive force graph of who's talking to whom
• TV Mode — vertical video feed with topic selector
• Gallery — pure image browsing with lightbox viewer
• Reader View — distraction-free article reading built in
• Direct Messages with real-time polling
• Compose with images, video, GIFs, link previews, and @mention autocomplete
• Share Extension — share anything from Photos or Safari directly to Bsky Dreams
• Background notifications with push badge support
• Timeline scrubber — explore posts by time

PRIVACY
Your app password is stored only in your device's secure Keychain — never
transmitted to any server other than bsky.social. All API calls go directly
to the Bluesky AT Protocol. No tracking. No analytics. No ads.

Requires a free Bluesky account. Generate an App Password at:
bsky.app → Settings → App Passwords
```

#### D4 — Keywords
- **What it is:** Up to 100 characters of comma-separated terms. These are not visible to users but directly affect search ranking. Do not repeat words already in your app Name or Subtitle — Apple already indexes those.
- **Enter:** `bluesky,atproto,social,fediverse,decentralized,feed,posts,twitter,mastodon,bsky`
- **Notes:**
  - Separate with commas, no spaces after commas (saves characters)
  - Include competitor names your audience might search (Twitter/X, Mastodon)
  - You can update keywords with every new version without triggering extra review scrutiny

#### D5 — Support URL
- **What it is:** A required URL where users can get help. Shown on the listing and used by Apple's review team.
- **Enter:** `https://bskydreams.com` or `https://github.com/bhwilkoff/Bsky-Dreams/issues`
- **Must be a live, reachable URL** — Apple checks this during review.

#### D6 — Marketing URL
- **What it is:** Optional link to a marketing/landing page. Shown on the listing.
- **Enter:** `https://bskydreams.com` if available, otherwise leave blank.

#### D7 — Version
- **What it is:** The "What's New" text shown when existing users see an update. For a first release (1.0), this is shown as the initial release notes.
- **Enter for 1.0:**
```
Welcome to Bsky Dreams — a powerful new Bluesky client for iPhone.

This is the initial release, featuring a full-featured feed, advanced search,
Network Constellation, TV Mode, Gallery, Reader View, Direct Messages,
and a native Share Extension.
```

---

### Section E: Build

#### E1 — Select Build
- **What it is:** Link your uploaded Xcode archive to this version.
- Click the **+** button, select your build from the list.
- If no builds appear, the archive hasn't finished processing yet (check the TestFlight tab — it should show "Ready to Submit").

#### E2 — Export Compliance (Encryption)
- **What it is:** US export law requires declaring whether your app uses encryption.
- **Answer:** Select **"No"** — Bsky Dreams does not implement any custom encryption. It uses HTTPS (which is exempt from export compliance requirements as of 2017).
- If prompted with "Does your app use, contain, or incorporate cryptography?" → **No** (standard HTTPS/TLS provided by the OS is exempt).

---

### Section F: App Review Information

#### F1 — Sign-In Required
- **Enter:** **Yes**

#### F2 — Demo Account — Username
- **Enter:** A real Bluesky handle you control, e.g. `bskydreams-review.bsky.social`
- Create a dedicated throwaway account at bsky.app for this purpose so you can share the password with Apple's reviewers without exposing your real account.

#### F3 — Demo Account — Password
- **Enter:** The app password (not the account password) for the demo account.
- Go to bsky.app → Settings → App Passwords → create one named "Apple Review"

#### F4 — Notes
- **What it is:** Free-form instructions for Apple's review team. This is your chance to explain anything unusual about your app and prevent unnecessary rejections.
- **Enter:**
```
This app requires a Bluesky account to function. Demo credentials are provided above.

WHAT THIS APP IS:
Bsky Dreams is a native iOS client for the Bluesky social network, which is built
on the open AT Protocol. All API calls go directly to bsky.social — there is no
custom backend server. The app does not collect or transmit user data to any server
other than bsky.social.

NAVIGATION:
- The sidebar on the left contains all navigation (tap the hamburger icon on the
  main screen to open it)
- Home, Search, Notifications, DMs, Gallery, TV, Reader, Analytics, Constellation,
  and Settings are all accessible from the sidebar

SHARE EXTENSION:
The app includes a Share Extension that allows sharing images, videos, and URLs
from Photos or Safari into a new post. To test: open the Photos app, select an
image, tap Share, and select Bsky Dreams.

NETWORK REQUIREMENT:
This is a social networking app that requires an internet connection to load
content. This is expected behavior.
```

#### F5 — Attachment
- **What it is:** Optional file (screenshot, video, PDF) you can attach to help reviewers understand the app. Max 1 file.
- **Enter:** Optional. If you have a short screen recording showing how to navigate the app, attach it. Otherwise leave blank — the Notes above are sufficient.

---

### Section G: Version Release Options

#### G1 — Release Method
- **What it is:** Controls when the app goes live after Apple approves it.
- **Options:**
  - **Automatically release this version after App Review approval** — goes live the moment Apple approves. Choose this.
  - **Manually release this version** — sits approved but not live; you release it by clicking a button. Use this if you want to time the launch.
  - **Automatically release this version after App Review approval, no earlier than [date]** — useful for coordinated launches.
- **Enter:** **Automatically release after approval** for a straightforward launch.

#### G2 — Phased Release
- **What it is:** Rolls out the update to a random percentage of users over 7 days (1% → 2% → 5% → 10% → 20% → 50% → 100%). Lets you catch crashes before hitting all users. Only applies to **updates**, not new app submissions.
- **Enter:** Leave off for v1.0 (it's a new app, not an update — there are no existing users to phase).

---

### Section H: In-App Purchases, Subscriptions, and Game Center

These sections appear in the left sidebar. For Bsky Dreams v1.0:

- **In-App Purchases:** Leave empty. The app is free with no paid features.
- **Subscriptions:** Leave empty.
- **Game Center:** Leave disabled. Not a game.

If you add premium features in a future version, you would create In-App Purchase products here first, then reference them in your app code via StoreKit.

---

### Step 2: Add a Privacy Manifest (required)

Create a file called `PrivacyInfo.xcprivacy` in your project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeOtherUserContent</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Drag this file into Xcode's Project Navigator and check the **BskyDreams** target checkbox.

### Step 3: Submit

Click **"Submit for Review"**.

Apple typically reviews new apps within **24–48 hours**.

**Common rejection reasons:**

| Rejection | Fix |
|-----------|-----|
| Missing demo account | Provide working Bluesky credentials in Review Notes |
| "App appears to be a web wrapper" | Add review notes explaining it uses the AT Protocol native API; all UI is SwiftUI |
| Privacy manifest missing or incomplete | Verify `PrivacyInfo.xcprivacy` is in the target and covers all API access |
| "Your app accesses the user's [Photos/Notifications] without sufficient justification" | Verify all NSUsageDescription keys are in Info.plist with clear explanations |
| Crashes on launch during review | Apple reviews on real devices; test on an actual iPhone, not just simulator |
| Share Extension crashes | Confirm App Group ID in the extension matches the main app exactly |

---

## Part 8: After Approval

### Updating the app

For future updates:
1. Increment **Version** (e.g. 1.1) in Xcode
2. Archive and upload a new build (Build number must be higher than previous)
3. In App Store Connect, click **"+ Version or Platform"**, create version 1.1
4. Attach the build and submit for review

### Monitoring

- **Crash reports:** Xcode Organizer → Crashes tab (requires users to share diagnostics)
- **Analytics:** App Store Connect → Analytics tab (downloads, sessions, retention)
- **Reviews:** App Store Connect → Ratings and Reviews tab
- **TestFlight feedback:** App Store Connect → TestFlight → Feedback

---

## Estimated Timeline

| Step | Time |
|------|------|
| Register App IDs + App Group (Part 3) | 30 minutes |
| Set up Xcode project | 1–2 hours |
| Add fonts + assets | 30 minutes |
| Local testing on device | 2–4 hours |
| Run screenshot tests (automated) | 30 minutes |
| Complete App Store metadata | 1 hour |
| Archive and upload | 30 minutes |
| TestFlight smoke test | 30 minutes |
| Apple review | 24–48 hours |
| **Total** | **~2 days** |
