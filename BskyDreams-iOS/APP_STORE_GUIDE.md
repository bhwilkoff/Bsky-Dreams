# BskyDreams iOS — Build & App Store Submission Guide

## Prerequisites

Before you begin, you need:
- A **Mac** running macOS 15 (Sequoia) or later
- **Xcode 26** (download from the Mac App Store or developer.apple.com)
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
   - **Bundle Identifier:** `com.bskydreams.app` *(or your own reverse-DNS identifier)*
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
- Select your Team
- The Bundle ID should be `com.bskydreams.app`
- Click **+ Capability** and add:
  - `Keychain Sharing` (for secure credential storage)
  - `Background Modes` → check "Background fetch" and "Audio, AirPlay, and Picture in Picture"

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
- [ ] Share sheet (share a post URL)
- [ ] Background → foreground token refresh

---

## Part 3: Preparing for the App Store

### Step 1: Create your App Store Connect record

1. Go to appstoreconnect.apple.com
2. Click **My Apps → +** (the plus button)
3. Fill in:
   - **Platform:** iOS
   - **Name:** Bsky Dreams
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** Select `com.bskydreams.app` from the dropdown (it appears after Xcode registers it)
   - **SKU:** `bskydreams-001` (any unique string)
   - **User Access:** Full Access
4. Click **Create**

### Step 2: App information

In your App Store Connect record:

**App Information:**
- Category: Social Networking
- Secondary Category: News (optional)
- Content Rights: Check "does not contain third-party content"
- Age Rating: Click "Edit" → answer all questions (no mature content, no user-generated adult content flag needed since Bluesky has content filtering)

**Pricing:**
- Set to **Free**

**App Privacy:**
- Data Types Collected:
  - **Name:** Yes (display name from Bluesky profile)
  - **Username:** Yes (Bluesky handle)
  - **Email Address:** Yes (stored in Keychain, not transmitted to us)
  - **Photos or Videos:** Yes (user uploads to Bluesky)
  - **User Content (Messages):** Yes (DMs via Bluesky's API)
- Data Use: "App Functionality" for all
- **Linked to Identity:** Yes for username/email
- **Tracking:** No (we don't track users across apps)

### Step 3: Screenshots and metadata

You need screenshots in these sizes (use iPhone simulators in Xcode):
- **6.9" iPhone 16 Pro Max** (required) — 1320×2868 or 1290×2796
- **6.7" iPhone Pro Max** (required for older devices) — 1242×2208
- **iPad Pro 13" M4** (required if targeting iPad) — 2064×2752

**Capturing screenshots in Xcode:**
1. Run the app in a simulator
2. Press **⌘S** or **Device → Take Screenshot**
3. Screenshots save to your Desktop

Recommended screenshots (5 max):
1. Home feed showing posts (Neubrutalist design)
2. Thread view with nested replies
3. Compose screen
4. Network Constellation visualization
5. TV mode / Gallery

**App Description (copy-paste ready):**
```
Bsky Dreams is a powerful Bluesky client that helps you get the most out of the AT Protocol social network.

Features:
• Smart home feed with Following and Discover tabs
• Advanced search with filters (date, author, language)
• Threaded conversations with depth visualization
• Network Constellation — explore who's talking to whom
• TV Mode — vertical video feed
• Gallery — pure image browsing
• Reader View — article reading mode with Readability.js
• Analytics Dashboard — engagement charts and post heatmap
• Direct Messages with 30-second polling
• Compose with images, link previews, and @mention autocomplete
• Native iOS share sheet support

Privacy-first: Your app password is stored only in your device's secure Keychain — never on any server. All API calls go directly to bsky.social.

Requires a Bluesky account. Create a free App Password at bsky.app → Settings → App Passwords.
```

**Keywords** (100 chars max):
`bluesky,atproto,social,fediverse,decentralized,feed,thread,twitter,mastodon,network`

**Support URL:** Your GitHub repo URL or a simple support page
**Marketing URL:** (optional)

### Step 4: Build settings for release

In Xcode:

1. Change the scheme from Debug to Release:
   - Click the scheme picker (next to the device picker)
   - **Edit Scheme → Run → Build Configuration → Release**

2. Set the version:
   - Project Navigator → BskyDreams target → General
   - **Version:** 1.0
   - **Build:** 1

3. Choose "Any iOS Device (arm64)" from the device picker

---

## Part 4: Archiving and Uploading

### Step 1: Archive the app

1. **Product → Archive** (⌘ is not available here, just use the menu)
2. Wait for the build to complete — this can take 2–5 minutes
3. The **Organizer** window opens automatically, showing your archive

### Step 2: Validate the archive

1. In Organizer, select the archive
2. Click **Validate App**
3. Choose **"Automatically manage signing"**
4. Click **Next** → **Validate**
5. Fix any issues reported (common: missing privacy descriptions, icon issues)

### Step 3: Upload to App Store Connect

1. In Organizer, click **Distribute App**
2. Choose **"App Store Connect"** → **"Upload"**
3. Click through the signing options (choose automatic)
4. Click **Upload**
5. Wait for upload to complete (1–10 minutes depending on connection speed)

### Step 4: Process in App Store Connect

1. In App Store Connect → your app → **TestFlight** tab
2. Wait 5–30 minutes for the build to process
3. Once it shows "Ready to Test", add yourself as an internal tester
4. Install via TestFlight on your device and do a final test pass

---

## Part 5: Submitting for Review

### Step 1: Prepare the 1.0 submission

In App Store Connect → your app → **iOS App** tab → **1.0 Prepare for Submission:**

1. **Screenshots:** Upload all required sizes
2. **App Preview:** Optional — short video of the app in action
3. **Promotional Text:** "The most powerful Bluesky client for iPhone"
4. **Description:** (paste from above)
5. **Keywords:** (paste from above)
6. **Support URL:** Required
7. **Build:** Click the "+" button and select your uploaded build
8. **Review Information:**
   - Sign-in required: YES
   - Username/password: Provide a demo Bluesky account (create a throwaway account at bsky.app for Apple's reviewers)
   - Notes: "This app requires a Bluesky account. We have provided demo credentials above. The app uses Bluesky's public AT Protocol API — no custom backend."

### Step 2: Submit for review

Click **"Submit for Review"**.

Apple typically reviews new apps within **24–48 hours**. Common rejection reasons and fixes:

| Rejection | Fix |
|-----------|-----|
| Missing demo account | Provide working Bluesky credentials in Review Notes |
| Privacy manifest missing | Add `PrivacyInfo.xcprivacy` to target (see below) |
| "App appears to be a web wrapper" | Add App Store screenshots showing native UI; review notes explaining it uses the AT Protocol |
| Login crashes | Test login on a real device before submitting |

### Step 3: Add a Privacy Manifest (required since 2024)

Create a file called `PrivacyInfo.xcprivacy` in your project:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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
    </array>
</dict>
</plist>
```

Add this file to your Xcode project (drag into Project Navigator, check the target checkbox).

---

## Part 6: After Approval

### Updating the app

For future updates:
1. Increment **Version** (e.g. 1.1) in Xcode
2. Archive and upload a new build
3. In App Store Connect, create a new version, attach the build, submit for review

### Monitoring

- **Crash reports:** Xcode Organizer → Crashes tab (requires users to share diagnostics)
- **Analytics:** App Store Connect → Analytics tab (downloads, sessions, retention)
- **Reviews:** App Store Connect → Ratings and Reviews tab

---

## Tips & Troubleshooting

**"The app requires a network connection to function" rejection**
- This is expected for a social app. In Review Notes, explain: "BskyDreams connects to bsky.social using the open AT Protocol. An internet connection is required to load social content. This is expected behavior for a social networking app."

**Signing errors**
- Make sure your Bundle ID in Xcode exactly matches what you set in App Store Connect
- Revoke and regenerate your distribution certificate if it expired

**App icon**
- Create a 1024×1024 PNG icon (no alpha channel, no rounded corners — Apple adds the mask)
- In Xcode, go to Assets.xcassets → AppIcon → drag your icon to the 1024pt slot
- Recommended: Use the coral (#FF5C35) cloud logo on a white background

**Launch screen**
- Xcode 15+ uses a static launch screen by default — you can set a background color and image in the project settings without creating a storyboard

---

## Estimated Timeline

| Step | Time |
|------|------|
| Set up Xcode project | 1–2 hours |
| Add fonts + assets | 30 minutes |
| Local testing | 2–4 hours |
| Prepare App Store metadata + screenshots | 2–3 hours |
| Archive and upload | 30 minutes |
| Apple review | 24–48 hours |
| **Total** | **~2 days** |
