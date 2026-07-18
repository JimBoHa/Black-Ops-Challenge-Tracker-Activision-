# Ops Tracker

Native SwiftUI iOS challenge tracker for Call of Duty: Black Ops 7.

## Current capabilities

- Camo, calling-card, daily, and weekly challenge dashboards
- Search and category filters
- Manual progress editing with local JSON persistence
- Activision account connection screen with secure Keychain session storage
- Sync adapter isolated behind `ActivisionService`
- Offline sample catalog for development and device testing

## Activision API limitation

Activision does not publish a supported third-party API for current camo, calling-card, daily, or weekly challenge progress. The app never asks for or stores an Activision password. `ActivisionService` accepts an existing SSO token and is ready for authorized endpoints, but returns an explicit unsupported response until Activision supplies access. Manual tracking remains fully functional.

## Run

1. Open `OpsTracker.xcodeproj` in Xcode 26 or newer.
2. Select the `OpsTracker` scheme.
3. Choose an iOS 17+ simulator or connected iPhone.
4. Set your signing team under **Signing & Capabilities** for a physical device.

No third-party dependencies.
