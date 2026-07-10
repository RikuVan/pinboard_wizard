# Credential Sync & Env Import Design

**Date:** 2026-07-10
**Status:** Approved (design) — pending implementation plan
**Topic:** Share credentials across Macs via iCloud Keychain and import credentials from a `.env` file

## Goal

Let a user configure Pinboard Wizard's credentials once and have them available
on every Mac they use, and optionally bootstrap all credentials from a `.env`
file instead of typing each value into Settings inputs. Covers all five
credential groups: Pinboard API token, OpenAI API key, Jina API key, S3 backup
config, and GitHub notes config + PAT.

## Constraints & Decisions

- **Platform:** macOS desktop only. All credentials already live in the macOS
  Keychain via `flutter_secure_storage` (v10) under five keys:
  `pinboard_credentials`, `ai_settings`, `backup_s3_config`,
  `github_notes_config`, `github_pat_token`.
- **Sync transport (decided):** iCloud Keychain, using the keychain item
  attribute `synchronizable` (`MacOsOptions(synchronizable: true)`). No custom
  server, no custom crypto — Apple handles end-to-end encryption. Requires the
  user to have iCloud Keychain enabled; devices are Macs on the same iCloud
  account. Custom sync channels (encrypted blob in S3/GitHub) were considered
  and rejected: they need their own crypto, conflict handling, and bootstrap
  credentials on every device.
- **Sync opt-in (decided):** A toggle in Settings, **default OFF**. No secret
  leaves the Mac until the user enables it. The toggle must be enabled on each
  Mac that wants to participate.
- **Env file semantics (decided):** **One-time import** via an explicit
  "Import from .env…" action in Settings. The Keychain remains the sole source
  of truth afterwards; the app never reads the file at launch or in the
  background. The file can be deleted after import.
- **Conflict rule for import (decided):** **Env always wins.** One confirmation
  dialog (listing found keys with masked values and a "replaces existing
  values" warning), then every key present in the file overwrites the stored
  value. Keys absent from the file are left untouched — import never clears
  anything.
- **Priority model (decided):** Manual edits and env imports are peers; the
  most recent write wins, locally and across Macs (keychain sync is
  last-writer-wins per item).
- **Architecture (decided):** Centralize keychain access in one injected
  `AppSecureStorage` wrapper (approach A). The four services currently owning
  `static const FlutterSecureStorage` instances are refactored to use it.
- **New dependency:** `file_selector` (native open dialog, sandbox-safe).
  Env parsing is hand-rolled (~30 lines); `flutter_dotenv` is built for bundled
  asset env files and is the wrong fit.
- **Docs:** README gains sections for both features (user interjection:
  README must be updated as part of this work).

## Architecture

### New: `AppSecureStorage` (`lib/src/common/storage/app_secure_storage.dart`)

Single wrapper around `FlutterSecureStorage`, registered in the service
locator. All keychain traffic goes through it.

- API: `read(key)`, `write(key, value)`, `delete(key)`, `containsKey(key)` —
  each applying `MacOsOptions(synchronizable: <current flag>)`.
- Owns the registry of the five known credential keys (listed above) used by
  sync migration.
- `syncEnabled` getter + `setSyncEnabled(bool)` which runs the migration
  described below.
- The toggle state itself is stored as an **always-local** keychain entry
  (`secrets_sync_enabled`, never synchronizable) — it cannot live in the synced
  set (chicken-and-egg) and the app has no other local preference store.
- Initialized (flag loaded) during async `setup()` in the service locator
  before dependent services are constructed.

### Refactor: storage injection

`FlutterSecureSecretsStorage`, `AiSettingsService`, `BackupService`, and
`GitHubCredentialsStorage` receive `AppSecureStorage` via constructor injection
(wired in `service_locator.dart`) instead of owning static
`FlutterSecureStorage` instances. No behavior change beyond the applied
options.

### New: `EnvImportService`

1. `parse(String contents)` — hand-rolled parser: `KEY=VALUE` lines, optional
   `export ` prefix, single/double quotes, `#` comments, CRLF tolerated.
   Unrecognized or unparseable lines are ignored and counted, never a blocker
   (an unrelated notarization `.env` simply reports its vars as ignored).
   Returns the recognized keys/values plus the ignored count.
2. `apply(result)` — writes **through the existing services**
   (`CredentialsService.saveCredentials`, `AiSettingsService.setOpenAiApiKey` /
   `setJinaApiKey`, `BackupService.saveConfiguration`,
   `GitHubCredentialsStorage.saveConfig`/`saveToken` as needed), so auth
   notifiers and listeners update live without a restart. S3/GitHub configs
   merge via `copyWith` — a file containing only `AWS_SECRET_ACCESS_KEY`
   updates just that field. When no GitHub config exists yet, import creates
   one with a freshly generated `deviceId` (UUID); `isConfigured` is set only
   when owner, repo, and token are all present. Returns a per-key
   success/failure summary.

### Recognized environment variables

| Group | Variables |
|---|---|
| Pinboard | `PINBOARD_API_TOKEN` |
| OpenAI / Jina | `OPENAI_API_KEY`, `JINA_API_KEY` |
| S3 backup | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET`, `S3_FILE_PATH` |
| GitHub notes | `GITHUB_PAT`, `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_BRANCH`, `GITHUB_NOTES_PATH` |

### UI (Settings)

New "Credentials" section containing:

- **iCloud sync toggle** with explainer copy: requires iCloud Keychain; must be
  enabled on each Mac. Enabling shows a confirmation stating *"Where a synced
  value already exists, it replaces this Mac's value."*
- **"Import from .env…" button** → native open dialog (`file_selector`) →
  confirmation dialog (found keys, masked values, overwrite warning) → import →
  per-key result summary.

## Sync semantics

A keychain item is either **local-only** or **synchronizable**; the attribute
is part of the item's identity and the app only queries the kind matching its
own toggle. The two sets are disjoint.

- **Toggle OFF (default):** app reads/writes local-only items. Synced items
  delivered by iCloud from other Macs sit dormant and invisible. Local edits
  never leave the Mac. No conflicts possible — worst case is intentional
  divergence.
- **Enabling sync (migration, per known key):**
  - If a synced value already exists (from another Mac) → adopt it: **synced
    set wins**. Consistent with the "env always wins" simplicity rule.
  - Else if a local value exists → rewrite it as synchronizable.
  - Local-only copies are deleted afterwards (safe: local deletes do not
    propagate).
- **Disabling sync (per known key):** copy the current synced value into a
  local-only item (a working snapshot), then stop reading the synced set. The
  synced originals are **left in iCloud untouched** — deleting a synchronizable
  item propagates deletion to every Mac and would destroy other machines'
  credentials. Disabling on one Mac never harms the others; the Mac drifts
  independently until re-enabled (synced-wins applies again).
- **Flag flip ordering:** the toggle state flips only after all keys migrate.
  Migration is idempotent (read → write-new → delete-old), so partial failure
  leaves the toggle unchanged and retry is safe.

## Error handling

- **iCloud Keychain disabled on the Mac:** synchronizable writes still succeed;
  items simply don't leave the device until iCloud Keychain is enabled. Not
  reliably detectable → handled by explainer copy, not detection logic.
- **Migration failure:** toggle unflipped, error shown, retry safe (see above).
- **Env import:** unparseable/unrecognized lines ignored and counted; per-key
  write failures reported in the result summary; file read failure
  (permissions) → error dialog.

## Testing

- **Parser unit tests:** quotes, `export` prefix, comments, CRLF, junk lines.
- **`EnvImportService` tests:** variable→service mapping, S3/GitHub `copyWith`
  merging, env-wins overwrite, absent-keys-untouched, per-key failure summary.
- **`AppSecureStorage` migration matrix** against a fake `FlutterSecureStorage`
  (following existing mocktail/in-memory-storage patterns): local→synced,
  synced→local snapshot, both-exist→synced-wins, disable-does-not-delete-synced,
  partial-failure-leaves-flag.
- **Cross-Mac sync** is not CI-testable → manual smoke checklist in the PR.

## Documentation

README gains two sections: **"Sync credentials across Macs (iCloud)"** (how it
works, per-Mac opt-in, iCloud Keychain requirement, disable semantics) and
**"Import credentials from a .env file"** (variable table, one-time-import +
env-wins priority rules, note that the file can be deleted after import).

## Out of scope

- iOS or non-Apple platforms; any custom sync backend.
- Watching the env file for changes / re-import on change.
- Per-key conflict UI for import or sync-enable (simplicity rule: env wins,
  synced set wins).
- Export of credentials to a file.
