# iOS Shortcut: Share to Bsky Dreams

This Shortcut adds **Bsky Dreams** to the iPhone share sheet. Once installed, you
can share any link or text to your Bsky Dreams compose view in one tap.

---

## What the Shortcut does

When you share a link (e.g. from Safari) or text (e.g. from Notes), the Shortcut
URL-encodes it and opens `https://bskydreams.com?view=compose&shareText=<encoded>`
in your browser. Bsky Dreams reads the parameter, pre-fills your compose box, and
auto-triggers link preview if the shared content is a URL.

---

## Step-by-step: Build the Shortcut

Open the **Shortcuts** app → tap **+** (top right) → tap the title at the top and
rename it **"Share to Bsky Dreams"**.

Then add the following 5 actions in order by tapping **Add Action** (or the `+` at
the bottom of the action list) and searching for each action name:

---

### Action 1 — Receive Input from Share Sheet

Search: **"Receive Input"**
Select: **Receive Input from Share Sheet**

The action will show **"Receive [Anything] from Share Sheet"**. Tap **Anything**,
deselect all types, then select only **URLs** and **Text**. Tap Done.

> This is the trigger that makes the Shortcut appear in the share sheet.

---

### Action 2 — Get Text

Search: **"Get Text"**
Select: **Get Text**

The action reads: **"Get Text from [Shortcut Input]"**

The blue **Shortcut Input** token should be pre-filled. If not, tap the input field
and select **Shortcut Input** from the variable list.

> Converts a URL object (from Safari) to a plain text string.

---

### Action 3 — URL Encode

Search: **"URL Encode"**
Select: **URL Encode**

The action reads: **"URL Encode [Text]"**

The blue **Text** token (output of Action 2) should be pre-filled. Confirm it says
**Text**, not something else.

> Encodes the text so special characters (spaces, &, ?, etc.) don't break the URL.

---

### Action 4 — Text  ← THIS IS THE KEY STEP

Search: **"Text"**
Select: **Text** (the simple action that just holds a block of text, under Scripting)

You'll see a large blank text field. **Tap inside it** to focus it and bring up the
keyboard. Now do the following in sequence:

1. **Type** (copy and paste is easiest):
   ```
   https://bskydreams.com?view=compose&shareText=
   ```
   Do **not** add a space or newline after the `=`.

2. With your cursor placed right after the `=`, look at the **row of icons above
   the keyboard** (the keyboard accessory bar). Tap the icon that looks like a
   **circle with a dot inside** or a **curly-brace `{x}`** — this is the
   **Insert Variable** button.

   > If you don't see the accessory bar, scroll the Shortcuts canvas so the text
   > field is roughly centred on screen, then tap inside it again.

3. A variable picker slides up. Tap **URL Encoded Text** (the output of Action 3).

The field should now read:
```
https://bskydreams.com?view=compose&shareText=▮URL Encoded Text▮
```
where `▮URL Encoded Text▮` is a blue rounded token, not plain text.

---

### Action 5 — Open URL

Search: **"Open URL"**
Select: **Open URL**

The URL field will show a placeholder. Tap it, clear any default content, then:

1. Tap the **Insert Variable** button above the keyboard (same `{x}` button as
   in Action 4).
2. Select **Text** (the output of Action 4 — the fully constructed URL).

The field should show a single blue **Text** token, nothing else.

---

## Enable in the Share Sheet

Tap the **settings icon** (top right, looks like a slider or an `i` circle) →
under **Details**, make sure **Show in Share Sheet** is toggled on.

Tap **Done**.

---

## Test it

1. Open Safari and navigate to any webpage.
2. Tap the share icon → scroll down in the share sheet → tap **Share to Bsky Dreams**.
3. Bsky Dreams should open directly to the compose view with the URL pre-filled
   and a link preview loading.

If the shortcut doesn't appear in the share sheet immediately, force-quit the
Shortcuts app, wait a moment, and try again.

---

## Publishing to iCloud (for the Settings install button)

Once you've confirmed the Shortcut works:

1. In the Shortcuts app, long-press **Share to Bsky Dreams** → tap **Share**.
2. Tap **Copy iCloud Link**.
3. Open `js/app.js` and replace the `null` on the `IPHONE_SHORTCUT_URL` line with
   your iCloud link:
   ```js
   const IPHONE_SHORTCUT_URL = 'https://www.icloud.com/shortcuts/YOUR_ID_HERE';
   ```
4. Commit and push — the **Install iOS Shortcut** button in Settings will appear
   automatically for all users.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Shortcut doesn't appear in share sheet | Toggle "Show in Share Sheet" off and on in Shortcut Details |
| Compose opens but text box is empty | Check Action 4 — make sure `URL Encoded Text` is a blue token, not typed text |
| Link preview doesn't trigger | The shared URL must start with `http://` or `https://`; bare domains won't trigger it |
| "Shortcut Input" not available in Action 2 | Delete Action 2 and re-add it; the variable auto-populates from Action 1 |
