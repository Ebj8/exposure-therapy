<img src="ExposureTherapy/ExposureTherapy/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Exposure Therapy app icon" width="96" align="right">

# Exposure Therapy

An iPhone app for culling your camera roll, one month at a time. Browse each month like a photo gallery: swipe to keep, swipe up to break up with the photos you don't want. Nothing is deleted until you say so, and nothing ever leaves your iPhone.

By Eli Johnson, published by DataThink.

## Features

- **Gallery browsing by month.** Swipe left or right through a month's photos; every undecided photo you swipe past is kept. Photos show at their original aspect ratio, never cropped.
- **Swipe up to break up.** The photo leaves the gallery and joins your exes for the session.
- **Filmstrip.** Thumbnails of the photos around the current one, so you can keep the best shot of a burst.
- **More than keep or delete.** Heart a photo to make it a Favorite in Photos, file it into an album, or undo any decision, including after a relaunch.
- **Your exes.** Review everything you broke up with and tap to rescue any of them. **Breakup** deletes the rest after iOS confirms; they go to Recently Deleted for 30 days.
- **Daily sessions.** A goal of 25, 50 or 100 photos a day, with confetti when you hit it. Sessions stay within one month.
- **Progress and stats.** Year and month grid, streaks with "new best", storage freed and percent of library reviewed. Finished months can be re-reviewed.
- **Daily reminder.** Optional local notification with rotating copy, skipped on days you've already hit your goal.

## Privacy

No accounts, no servers, no analytics, no ads, no tracking. The app collects no data. Decisions and stats are stored on the device with SwiftData; settings with `@AppStorage`. See the [privacy policy](docs/privacy.md).

## Tech stack

- iPhone only, iOS 17.6+, Swift and SwiftUI
- PhotoKit for reading, favoriting, filing into albums and deleting photos
- SwiftData for decisions, sessions and deletion records
- UserNotifications for the daily reminder
- No third-party dependencies

## Getting started

1. Open `ExposureTherapy/ExposureTherapy.xcodeproj` in Xcode 26.3 or later.
2. Select the **ExposureTherapy** target → **Signing & Capabilities** and choose your team.
3. Pick an iPhone or Simulator and press **⌘R**.

**Testing tips**

- Previews use generated sample photos (`Preview/PreviewData.swift`) and never touch your real library.
- The Simulator ships with only a few photos. Drag images onto the Simulator window to add more.
- Try Breakup in the Simulator first. On a real phone, deleted photos stay in **Recently Deleted** for 30 days.

## Project layout

```
ExposureTherapy/ExposureTherapy/
├── App/              App entry, navigation routes, settings keys, reminder sync
├── Design/           Colors, type, buttons, skeleton and confetti views
├── Library/          PhotoKit access, library index, image loading, queues, stats, reminders
├── Models/           SwiftData models: PhotoDecision, DeletedPhoto, Session
├── Screens/
│   ├── Access/       Welcome and photo-access screens
│   ├── Home/         Stats, today's session card, year grid
│   ├── SwipeDeck/    Gallery deck, filmstrip, album picker, deck model
│   ├── YourExes/     Review and Breakup
│   ├── SessionComplete/
│   └── Settings/     Settings and acknowledgements
├── Preview/          Sample data for SwiftUI Previews
├── Resources/        Bundled fonts and their licenses
└── PrivacyInfo.xcprivacy
```

## Docs

| File | What it is |
| --- | --- |
| [`SPEC.md`](SPEC.md) | The product and build spec, kept in sync with the app |
| [`CLAUDE.md`](CLAUDE.md) | Working rules for building the app with Claude |
| [`docs/`](docs) | Support page and privacy policy, published with GitHub Pages |
| [`AppStore/Listing.md`](AppStore/Listing.md) | App Store listing copy, review notes and screenshot plan |
| [`Design/`](Design) | Original mockups (from before the gallery redesign) |

## Status

Version 1.0 is feature-complete and prepared for App Store submission (privacy manifest, encryption declaration, listing drafts). Next: developer program enrollment, TestFlight and review.

## License

The app's code is released under the [MIT License](LICENSE). Copyright (c) 2026 Eli Johnson.

The bundled fonts are not covered by the MIT License. They keep their own license (see Credits).

The **Exposure Therapy** name and the app icon (the image files in `ExposureTherapy/ExposureTherapy/Assets.xcassets/AppIcon.appiconset` and `AppIconImage.imageset`) are not covered by the MIT License either; all rights reserved. You're welcome to fork and build on the code, but please give your version a different name and icon.

## Credits

Fonts: [Bricolage Grotesque](https://github.com/ateliertriay/bricolage) and [Inter](https://github.com/rsms/inter), both under the SIL Open Font License 1.1. License texts ship with the app in `Resources/Licenses`.
