# PomoLedger

A Pomodoro-style focus timer for iOS, iPadOS, and macOS. PomoLedger tracks focus and break sessions, lets you record an intention for each session, and keeps a history you can review, export, or sync across your own devices.

## Features

- Focus / break timer with configurable durations
- Session intentions, tracked and recorded even when a session isn't completed
- Session history and recap view
- Calendar export — add completed sessions directly to a calendar of your choice
- Optional iCloud sync of session data across your own devices
- Live Activity / Dynamic Island countdown (iOS/iPadOS)
- Menu bar mini-player during focus sessions (macOS)

## Platforms & Requirements

- iOS 17+, iPadOS 17+, macOS 14+
- Built with SwiftUI and WidgetKit
- Xcode 16 or later to build from source

## Building

1. Clone the repository.
2. Open `PomoLedger.xcodeproj` in Xcode.
3. Select the `PomoLedger` scheme and a simulator or device.
4. Build and run.

The `PomoWidgExtension` target provides the Live Activity widget and is embedded automatically when building the main app.

## Support

Found a bug or have a feature request? Open an issue on this repository, or reach out at pomo@scruggsfam.rocks.

## Privacy Policy

_Last updated: September 6, 2026_

This section serves as PomoLedger's privacy policy for App Store purposes.

### Summary

PomoLedger does not collect, transmit, or sell any personal data to its developer or to any third party. There are no accounts, no analytics SDKs, no advertising SDKs, no crash-reporting services, and no servers operated by the developer. The app has no network access beyond Apple's own system frameworks described below.

### Data stored on your device

Your session history, timer settings, and session intentions are stored locally on your device by the app. This data is never transmitted to the developer or to any third party.

### iCloud (optional)

If you choose to enable iCloud storage in Settings, your session data files are saved to your personal iCloud account via Apple's iCloud Drive. This lets your session history sync across your own devices signed into the same Apple ID. This data is stored in your iCloud account under your control — the developer has no access to it. See Apple's [iCloud privacy practices](https://www.apple.com/legal/privacy/en-ww/) for how Apple handles iCloud data.

### Calendar access (optional)

If you enable calendar export in Settings, PomoLedger uses Apple's EventKit framework to add your completed focus sessions to a calendar you choose in the Calendar app. This requires your explicit permission (requested the first time you enable the feature) and happens entirely on your device. No calendar data is sent to the developer or any third party.

### Notifications

PomoLedger schedules local notifications on your device to alert you when a focus or break session ends. These are generated entirely on-device and are not push notifications delivered through a remote server.

### Third-party services

PomoLedger does not integrate any third-party analytics, advertising, or crash-reporting SDKs.

### Children's privacy

PomoLedger is not directed at children and does not knowingly collect personal information from children.

### Changes to this policy

Any changes to this privacy policy will be posted on this page with an updated "Last updated" date above.

### Contact

Questions about this policy can be sent to pomo@scruggsfam.rocks.

## License

© 2026 PomoLedger. All rights reserved.
