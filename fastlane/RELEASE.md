# App Store Metadata

This folder manages App Store Connect metadata through fastlane. It does not affect Xcode builds unless a fastlane lane is run manually.

Current workflow:

1. Archive and upload the App Store build from Xcode Organizer.
2. Update `fastlane/metadata/*/release_notes.txt` for the release.
3. Upload metadata:

```sh
fastlane mac upload_metadata
```

To target a specific App Store Connect version:

```sh
fastlane mac upload_metadata version:2.2.1
```

When `version:` is omitted, the lane reads the current Xcode marketing version from `ExcalidrawZ.xcodeproj`. It prints the target version and locales, then asks for confirmation before uploading.

Authentication uses an App Store Connect API key with App Manager access.

Create a local ignored file at `fastlane/.env.local`:

```env
APP_STORE_CONNECT_API_KEY_ID=...
APP_STORE_CONNECT_API_ISSUER_ID=...
APP_STORE_CONNECT_API_KEY_PATH=./fastlane/AuthKey_XXXXXXXXXX.p8
```

Keep the downloaded `.p8` file under `fastlane/` or another local path. The `.env.local` file and API key files are ignored by git.

Managed metadata files per locale:

- `name.txt`
- `subtitle.txt`
- `keywords.txt`
- `promotional_text.txt`
- `description.txt`
- `release_notes.txt`

Current metadata locales:

- `en-US`
- `ar-SA`
- `pl`
- `de-DE`
- `ru`
- `fr-FR`
- `zh-Hant`
- `ko`
- `nl-NL`
- `zh-Hans`
- `pt-BR`
- `ja`
- `th`
- `tr`
- `es-ES`
- `it`
- `vi`

The current lane skips binary and screenshot upload. Build/archive automation can be added later after the manual release flow is stable.

## Sparkle Release Notes

Sparkle release notes reuse the same `fastlane/metadata/*/release_notes.txt` source as App Store Connect.

Generate localized Sparkle HTML files and patch the local website appcast:

```sh
fastlane mac generate_sparkle_release_notes version:2.2.1
```

This writes files like:

```text
WebPage/public/downloads/ExcalidrawZ.2.2.1.en-US.html
WebPage/public/downloads/ExcalidrawZ.2.2.1.zh-Hans.html
```

If `WebPage/public/downloads/appcast.xml` already contains an item for that version, the lane replaces its release notes link with localized Sparkle links:

```xml
<sparkle:releaseNotesLink xml:lang="en-US">...</sparkle:releaseNotesLink>
<sparkle:releaseNotesLink xml:lang="zh-Hans">...</sparkle:releaseNotesLink>
<sparkle:releaseNotesLink xml:lang="zh-Hant">...</sparkle:releaseNotesLink>
```

The existing appcast generation script should run before this lane when publishing a new non-App Store build.
