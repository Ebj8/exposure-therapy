# Exposure Therapy – v1 Build Spec

Nov 20, 2026 · @Eli

## Overview

Exposure Therapy is a personal iPhone app for culling the camera roll one photo at a time with dating-app swipes: right to keep (a match), left to delete (an unmatch). v1 is for your own phone only, with no App Store work. Design reference: [Exposure Therapy – App Mockups](https://claude.ai/artifact/Mi36rrZw3suPjjcyheqKVE).

**Tech stack**

- iPhone only, iOS 17 or later, SwiftUI, built in Xcode 26.3+ with the Claude Agent.
- PhotoKit for reading, favoriting, adding to albums and deleting photos.
- SwiftData for local progress; `@AppStorage` for settings.
- UserNotifications for the daily reminder.
- No backend, no accounts, no analytics. Nothing leaves the phone.

**In scope for v1**

- Four screens: Home, Swipe deck, Your exes, Session complete, plus a plain Settings screen.
- Two ways in: a daily session (50 photos by default) and browsing by month.
- Keep, unmatch, heart (Favorite), add to album, and undo.
- Deletes batched at the end of each session, behind one Breakup button.
- Stats: streak, storage freed, % of library reviewed, month status. Daily reminder.

**Out of scope for v1**

- Videos, Live Photo special handling, smart decks (screenshots, duplicates, On This Day).
- iPad, iCloud sync of progress between devices, App Store listing or paywall.

## Design system

Put every color below in the asset catalog as a named color, and use the names in code, never raw hex values.

| Name | Hex | Used for |
| --- | --- | --- |
| rose | #D81F5E | Primary buttons, progress fills, in-progress month border, heart, app icon background |
| roseDark | #A8124A | Text on blush backgrounds, pressed state |
| blush | #FFE3EC | Pills, in-progress month fill, exes chip |
| cream | #FFF4F1 | App background |
| plum | #23121C | Main text, Today's session card, Session complete background |
| plumRaised | #3A2531 | Stat tiles on the Session complete screen |
| muted | #6E5A64 | Secondary text, chevrons |
| line | #F3DAD3 | Progress tracks, card borders |
| teal | #0B6E6E | Keep / MATCH stamp, done months, "Back together" badge |
| tealLight | #DDF1EF | Done badge backgrounds |
| coral | #D9442B | Unmatch button and UNMATCH stamp, delete badges |
| white | #FFFFFF | Cards, buttons on cream |

**Type**

- Headings and big numbers: Bricolage Grotesque ExtraBold (Google Fonts, SIL Open Font License). Titles 34 pt, card headlines 26 pt, section headers 19–20 pt, stat numbers 24–28 pt.
- Body: Inter Regular, SemiBold and Bold, 12–16 pt. SF Pro is an acceptable fallback if bundling Inter is a hassle.
- Bundle the .ttf files and list them under `UIAppFonts` in Info.plist. Support Dynamic Type where it doesn't break the card layouts.

**Shape and spacing**

- Screen padding 20 pt; 10–18 pt gaps between blocks.
- Corner radius: stat tiles and month tiles 14–18 pt, cards 20–26 pt, swipe card 30 pt. Buttons are pills (fully rounded).
- Minimum tap target 44 × 44 pt. Icons are SF Symbols, stroked, never emoji.

**App icon (Pinned Keeper)**

- Rose (#D81F5E) background. A white polaroid tilted about 5° with a light-blue sky, pale sun and green hills in the picture area.
- A plum (#23121C) heart pushpin at the top center, with a thick white outline so it stands off the pink.
- Needs a 1024 × 1024 PNG with no transparency. In-app, the header shows it at 40 pt with a 10 pt corner radius.

**Voice**

Cheeky dating-app humor. Kept photos are matches; deleted photos are exes or unmatches; the delete button is Breakup. Keep the jokes in headlines and buttons. Warnings and counts stay plain and accurate.

## Screens

Four screens make one loop: Home → Swipe deck → Your exes → Session complete → Home. Text in quotes is the exact copy; `{braces}` are live values.

### 1. Home

1. **Header:** the app icon at 40 pt, then "Exposure Therapy" (Bricolage, 19 pt). A 44 pt round Settings button on the right.
2. **Title:** "Ready to let go?" (34 pt). Subtitle in muted: "Your camera roll misses you. Some of it, anyway."
3. **Three stat tiles** (white, side by side):
   - Flame icon in rose, "{streak}", "day streak".
   - Trash icon in teal, "{storage freed}" (e.g. "3.2 GB"), "let go".
   - Photo icon in plum, "{percent}%", "reviewed".
4. **Today's session card** (plum background, white text):
   - Eyebrow "TODAY'S SESSION" in light pink, "about {minutes} min" on the right (estimate 6 seconds per photo).
   - Headline "{count} photos are waiting to hear back."
   - "Picking up where you left off in {Month Year}."
   - Rose pill button "Start swiping →" opens the Swipe deck in daily mode.
   - When today's session is done: headline "You're all caught up today." and button "Keep going anyway".
5. **Library progress:** "Your whole library" with "{reviewed} of {total} photos" on the right, and a 10 pt progress bar in rose.
6. **Year grid:**
   - Round chevron buttons on either side of the year title (e.g. "2019"), with "{done} of 12 months done" under it.
   - A 6 × 2 grid of month tiles ("Jan" to "Dec"):
     - Done: teal tile, white label and a checkmark.
     - In progress: white tile with a 2 pt rose border; a blush fill rises from the bottom to match the percent, with "{n}%" under the label.
     - Not started: white tile, muted label.
     - No photos that month: tile at 40% opacity, not tappable.
   - Opens on the year of the month in progress. Tapping a month opens the Swipe deck for that month.
   - No legend under the grid.

### 2. Swipe deck

1. **Top bar:** a round back button; in the center "{Month Year}" with "{position} of {total} today" (daily mode) or "{position} of {total}" (month mode); a plum "Done" pill on the right that opens Your exes.
2. A thin rose progress bar for the session.
3. **Card stack:**
   - The current photo fills a card with a 30 pt radius and a soft shadow.
   - The next photo peeks out behind it, rotated 3°.
   - Two dark translucent chips along the bottom: date and time ("Jun 14, 2019 · 8:42 PM") and file size ("2.4 MB").
4. **Hint line:** "Right to keep · left to unmatch · double-tap to heart". Hide it after the first 10 decisions.
5. **Button row,** left to right:
   - Undo (48 pt).
   - Unmatch ✕ (68 pt, white with a coral border).
   - Add to album (48 pt).
   - Heart (48 pt).
   - Match ✓ (68 pt, teal fill).
6. **Exes chip:** a blush pill, "✕ {n} exes this session". Tapping it opens Your exes.
7. When the queue runs out, go to Your exes automatically.

### 3. Your exes

1. Back button (returns to swiping), "{Month Year} session" label, title "Your exes", subtitle "Having second thoughts? Tap a photo to take it back."
2. **A scrollable 4-column grid of every ex in this session:**
   - Marked for delete: dimmed, with a small coral ✕ badge in the corner.
   - Tapped (rescued): full brightness, a 3 pt teal border and a "Back together" label. Tapping again un-rescues it.
3. **Warning card** (white, line-colored border, warning icon): "**This is goodbye.** {count} photos will move to Recently Deleted and disappear for good after 30 days." The count updates live as photos are rescued.
4. **"Breakup" button:** full-width rose pill with a broken-heart icon. It runs the delete (section 5); on success it goes to Session complete.
5. Text link: "Not yet, keep swiping".
6. With zero exes, skip this screen and go straight to Session complete.

### 4. Session complete

1. Plum background. A 112 pt rose circle with a white broken heart, rotated −8°.
2. "It's not you, it's me." (36 pt, two lines). "(It's you. You were blurry.)" under it. With zero deletes, use "Love is in the air." and "(You kept everything. No notes.)"
3. **2 × 2 stat tiles** (plumRaised):
   - "{n}" exes let go.
   - "{n}" matches kept.
   - "{size}" freed up.
   - "{n} days" streak, in pink; add "new best" when it's a record.
4. **Teal banner,** only when this session finished a month: "{Month Year} is done" and "Library now {percent}% reviewed".
5. **Reminder row:** "Remind me tomorrow" and "8:00 PM · keep the streak alive", with a toggle bound to the reminder setting.
6. **Buttons:** "Back home" (white pill) and "Keep going: {next month}" (outline pill) to start the next unfinished month.

### Settings (no mockup; keep it a plain list)

- Daily session size: 25, 50 or 100.
- Daily reminder on/off and time.
- "Reset progress" behind a confirmation alert. It clears decisions and stats only, never photos.

## Gestures and interactions

Every gesture also has a button, so the app is usable without swiping. Nothing is deleted from Photos until the Breakup button.

| Input | Decision | What changes in Apple Photos |
| --- | --- | --- |
| Swipe right, or ✓ | Keep (match) | Nothing |
| Swipe left, or ✕ | Unmatch | Nothing yet; the photo joins this session's exes |
| Double-tap the card, or the heart button | Heart, which also keeps | Marked as a Favorite |
| Album button | Keep and file | Added to the chosen album |
| Undo | Reverses the last decision | Removes the Favorite or album add if that decision made it |
| Tap a tile in Your exes | Rescue / un-rescue | Nothing |
| Breakup | Deletes all un-rescued exes | Moved to Recently Deleted after iOS confirms |

**Swipe feel**

- The card follows the finger and rotates up to 12° in the direction of the drag.
- A teal "MATCH" stamp (top-left, tilted −14°) fades in when dragging right. A coral "UNMATCH" stamp (top-right, tilted 14°) fades in when dragging left. Opacity follows drag distance.
- Commit when the card passes 120 pt or the flick is fast; it flies off-screen and the next card scales up into place. Otherwise it springs back.
- Buttons play the same fly-off animation.
- Double-tap shows a rose heart that pops and fades over the photo, then the card flies right.

**Album picker**

- A half-height sheet listing your albums (newest first) with a "New album…" row at the top.
- Choosing an album adds the photo, closes the sheet and moves to the next card.
- Remember the last album used and pin it to the top of the list.

**Undo**

- Undo works back through every decision in the current session.
- The card slides back in from the side it left.

**Haptics**

- A light impact on each decision.
- A soft double tap on a heart.
- A success notification after a Breakup completes.

## Data, PhotoKit and deletion

Apple Photos is the source of truth for the photos. SwiftData stores only your decisions and stats, keyed by each photo's `localIdentifier`.

**Photo access**

- Request access with `PHPhotoLibrary.requestAuthorization(for: .readWrite)` on first launch, from a short welcome screen.
- Info.plist `NSPhotoLibraryUsageDescription`: "Exposure Therapy shows your photos one at a time so you can decide which to keep. Nothing leaves your iPhone."
- If access is limited, show a banner on Home: "You've shared only some photos. Allow full access to review your whole library." The banner has a button that opens Settings.
- If access is denied, show a full-screen explainer with the same Settings button.

**Reading the library**

- Fetch images only (`PHAsset.fetchAssets(with: .image, …)`), sorted by `creationDate`, oldest first.
- Group photos by year and month of `creationDate` in the phone's calendar. Photos with no date go in a final "Undated" bucket.
- Load images with `PHCachingImageManager`:
  - Prefetch the next 3 cards at screen size and grid thumbnails at 200 pt.
  - Set `isNetworkAccessAllowed = true` so iCloud-only photos download; show a spinner on the card while they do.
- Observe `PHPhotoLibraryChangeObserver` and refresh counts when the library changes.

**SwiftData models**

| Model | Fields | Notes |
| --- | --- | --- |
| `PhotoDecision` | `assetID` (unique), `decision` (keep, heart, album, unmatch), `decidedAt`, `sessionID` | One row per reviewed photo. An unmatch stays "pending" until its Breakup succeeds |
| `DeletedPhoto` | `assetID`, `bytes`, `deletedAt`, `monthKey` | Kept after deletion so stats survive the photo being gone |
| `Session` | `id`, `mode` (daily or month), `monthKey`?, `startedAt`, `endedAt`?, `keptCount`, `deletedCount`, `bytesFreed` | A session ends at a Breakup, or at Done with zero exes |

- Settings in `@AppStorage`: `dailyGoal` (default 50), `reminderEnabled` (default false), `reminderTime` (default 20:00), `lastAlbumID`.
- An unfinished session (pending exes, no Breakup yet) survives quitting the app. Resume it the next time Swipe or Exes opens.

**Queues**

- Daily session: the next `dailyGoal` unreviewed photos, starting in the oldest month that isn't done and continuing into later months.
- Month mode: every unreviewed photo in that month, in date order.
- A photo is reviewed once it has a keep, heart or album decision, or has been deleted.

**Deletion (Breakup)**

1. Collect the un-rescued exes as `PHAsset`s.
2. Read each photo's size before deleting. Size comes from `PHAssetResource`'s `fileSize` via key-value coding; it's an undocumented key, which is fine for a personal app.
3. Call `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets) }`. iOS shows its own "Delete {n} photos?" confirmation.
4. If it succeeds, write `DeletedPhoto` rows, close the session and go to Session complete.
5. If you cancel or it fails, nothing is recorded as deleted. Stay on Your exes, with the exes still marked.

## Stats, streaks and reminders

Every stat is computed from the SwiftData records, so nothing is double-counted.

| Stat | Rule |
| --- | --- |
| Streak | Consecutive calendar days, ending today or yesterday, with at least one finished session that had 1+ decision. Also store the best streak to show "new best" |
| Storage let go | Sum of `DeletedPhoto.bytes`, shown in MB below 1 GB and in GB with one decimal above |
| % reviewed | Reviewed photos ÷ (photos in the library now + deleted photos), rounded down |
| Month status | Done: every photo in the month is reviewed. In progress: some are. Not started: none are |
| Minutes estimate | Queue size × 6 seconds, rounded up to whole minutes |

**Daily reminder**

- Ask for notification permission the first time the reminder toggle is turned on, not at launch.
- When on, schedule a repeating daily notification at `reminderTime` with `UNCalendarNotificationTrigger`.
- If today's session is finished before reminder time, skip today's notification and keep the following days.
- Rotate the notification text:
  - "{n} photos are waiting to hear back."
  - "Your camera roll misses you."
  - "Don't leave {Month Year} on read."
  - "Your {streak}-day streak is on the line." (only when the streak is 2 or more)
- Tapping the notification opens the app on Home.

## Build order

Build in nine milestones, one per Claude conversation. Each ends with something you can run on your phone. Commit to Git after each one.

1. **Foundation:** project settings, named colors, bundled fonts, a placeholder icon, the photo-library permission text, and the app shell with navigation between empty screens.
   - *Done when:* the app launches on your phone to a cream Home screen with the header and title.
2. **Photo library:** permission flow, fetching and grouping by month, the SwiftData models, and the Home year grid and library progress wired to real data.
   - *Done when:* Home shows your real photo count and real months.
3. **Swipe deck:** card stack, drag gesture, stamps, the fly-off animation, keep and unmatch buttons, image prefetching, and month mode.
   - *Done when:* you can tap a month and swipe through it, and decisions survive a relaunch.
4. **Heart, albums and undo:** double-tap and the heart button, the album picker sheet, and a multi-step undo that reverses Photos changes.
   - *Done when:* hearted photos show as Favorites in Apple Photos, and undo removes them again.
5. **Your exes and Breakup:** the review grid, rescue toggling, the live warning count, and the PhotoKit delete with cancel handling.
   - *Done when:* Breakup deletes only the un-rescued photos, after iOS confirms.
6. **Session complete and stats:** the complete screen, the stat rules, the streak and "new best", and the month-done banner.
   - *Done when:* the numbers on Home and Complete match what you actually did.
7. **Daily session:** the daily queue, the Today's session card states, and the minutes estimate.
   - *Done when:* Start swiping serves 50 photos across months, and the card flips to "all caught up".
8. **Reminders and Settings:** notification permission, the repeating reminder with rotating text, and the Settings list with reset.
   - *Done when:* a reminder arrives at the chosen time and skips days you already swiped.
9. **Polish:** haptics, the hint auto-hide, empty and limited-access states, Dynamic Type checks, and the final app icon.
   - *Done when:* you'd happily use it every night.

## How to prompt Claude in Xcode

Put this spec inside the project and give Claude one milestone at a time. Ask for a plan before code, and test on your phone before moving on.

**One-time setup**

1. In Xcode: File → New → Project → iOS → App.
   - Product name `ExposureTherapy`, interface SwiftUI, storage SwiftData.
   - Signing: your personal team.
2. Export this doc as Markdown, save it as `SPEC.md` in the project's root folder, and commit it.
3. Optional: save screenshots of the four mockup screens into a `Design/` folder. If Xcode's chat lets you attach images, attach the matching screenshot when you start a screen.
4. Create `CLAUDE.md` in the root folder with the standing rules below. Claude Code reads this file automatically. If Xcode's agent doesn't seem to, start each conversation with "Read CLAUDE.md and SPEC.md first."
5. In Xcode → Settings → Intelligence, sign in to Claude. Start a new conversation for each milestone so the context stays focused.

**CLAUDE.md**

```markdown
# Exposure Therapy – working rules

- SPEC.md is the source of truth. Read the sections relevant to the task before writing code.
- Build only what the current milestone asks for. No extra features, no third-party packages.
- SwiftUI + SwiftData + PhotoKit, iOS 17+, iPhone only. Use async/await.
- Colors come from the asset catalog by name (rose, plum, cream...). Never hard-code hex in views.
- Use the exact copy from SPEC.md, including punctuation.
- Every view gets a #Preview that uses sample data, never the real photo library.
- After changes: build, fix all errors and warnings, and check the Previews before saying you're done.
- Never delete photos except through the Breakup flow in SPEC.md section "Deletion (Breakup)".
- End each task with a short list of what changed and how to test it on device.
```

**First prompt (milestone 1)**

```text
Read CLAUDE.md and SPEC.md. We're building Exposure Therapy one milestone at a time.

Start with Milestone 1 (Foundation) from the "Build order" section.
Before writing code, give me a short plan: the files you'll create, the folder structure, and anything you need from me (for example, the font files).
Wait for my OK, then build it.
```

**Prompt for each later milestone**

```text
Milestone {n} ({name}) from SPEC.md is next. Milestones 1–{n-1} are done and committed.

Re-read the SPEC sections this milestone touches: {e.g. "Screens → Swipe deck", "Gestures and interactions"}.
Plan first: list the files you'll add or change and any open questions. Then build it, check the Previews, and tell me how to test it on my phone.
Meet the "Done when" line exactly. Don't start the next milestone.
```

**Fixing things**

- Point at one thing and quote the spec: "The MATCH stamp should be tilted −14° and teal per SPEC.md; right now it's flat and black. Fix only that."
- For a build error, paste the whole error message and ask for the smallest fix.
- If Claude drifts off the design, say "Compare the Home screen to SPEC.md section 1 line by line and list every difference before changing anything."

**Testing tips**

- Previews and the Simulator can't see your real library. Drag a few dozen photos onto the Simulator window to load test photos.
- Test Breakup on the Simulator first. On your phone, deleted photos stay in Recently Deleted for 30 days if anything goes wrong.
- Commit after every milestone so you can roll back a bad change with one click.
- If a milestone gets messy, start a fresh conversation with the milestone prompt. That usually beats arguing with a confused context.
