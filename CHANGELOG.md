# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.2] - 2026-10-14

### Fixed
- `site_settings_show` / `site_settings_update` return a `preview_url` per mark that API clients such as ChatGPT can open. It was an app-relative path to the Attachable preview route (`/recording_studio_attachable/attachments/<id>/preview/<variant>`), which needs a signed-in session. It is now an absolute Active Storage redirect URL (`/rails/active_storage/representations/redirect/<signed blob id>/<variation key>/<filename>`) with a blob id that is signed, tamper-proof, and expires after `config.preview_url_expires_in` (default 10 minutes); no session needed. The host comes from `config.public_url_options`, else `Rails.application.routes.default_url_options` with a host, else the current request's base URL (captured by the new `RecordingStudioSiteSettings::RequestBaseUrl` middleware). The Attachable preview route is not opened up, and `Logo#preview_url` and the Site screen keep using it.
- Logo download failures now say which check failed. The 422 `message` is `Logo could not be used: <field> <reason>` (it was only `Logo could not be used`), a refused address names the address (`host resolves to a non-public address (198.18.0.1)`), and network failures say whether the host timed out, TLS/certificate verification failed, the connection failed, or the response was invalid.

### Added
- `config.remote_image_allowed_networks` (or `RECORDING_STUDIO_SITE_SETTINGS_REMOTE_IMAGE_ALLOWED_NETWORKS`, comma-separated CIDRs): opt-in ranges a logo download may reach even though they are private or reserved, for sandboxes whose egress proxy answers every DNS lookup with its own address (e.g. fake-IP `198.18.0.0/15`). Loopback, link-local/metadata, and unspecified addresses stay refused. Empty by default, so production behavior is unchanged.

## [0.4.1] - 2026-10-14

### Changed
- Dependency bump only: `recording_studio_accessible` to `v0.18.0` (#25). The `v0.4.1` tag points at that commit, whose `VERSION` still read `0.4.0`; the preview URL, logo error and allowed-network changes listed under 0.4.2 are not in `v0.4.1`.

## [0.4.0] - 2026-10-14

### Added
- `site_settings_update` takes one optional top-level field per mark: `square_logo_file`, `wide_logo_file`, `favicon_file` (`<slot>_file` for each `Admin::MARK_VARIANTS` slot). A value is a file object `{ download_url, file_id }` (ChatGPT's shape), an https URL string, or `null` to remove the mark. `name` is now optional; send `name`, mark fields, or both.
- The update endpoint's openapi declares the mark fields under `x-mcp-file-params` (nullable). RecordingStudio MCP 0.14+ turns them into ChatGPT file params (`_meta["openai/fileParams"]`). No MCP dependency.
- `RecordingStudioSiteSettings::Api::RemoteImage` downloads marks: https on 443, up to 3 redirects with every hop re-resolved, private/loopback/link-local/metadata addresses refused and the connection pinned, short timeouts, the Site screen's Attachable `max_file_size`, and PNG/JPEG/WebP sniffed from the bytes. SVG is refused.
- `Store.update!` takes `clear:` (slot names) and removes those marks through Attachable `RemoveAttachment`.
- `site_settings_show` marks include `variant`.

### Changed
- The update input contract types only `name` and no longer rejects unknown keys itself; the handler rejects unknown fields with 422 `invalid_input`, as before.
- Mark problems, and an update with neither `name` nor a mark field, return 422 `invalid_input` with per-field `details`. Nothing is saved when any mark fails.
- Update checks `Store.authorize_write!` before downloading anything.

### Upgrade notes
- Clients that relied on `name` being required now get 422 `invalid_input` from the handler instead.
- For ChatGPT uploads, run RecordingStudio MCP 0.14.0 or newer.

## [0.3.0] - 2026-10-14

### Added
- Operations (Admin) API endpoints `site_settings_show` (`GET site_settings`) and `site_settings_update` (`PATCH site_settings`), registered from `config.to_prepare` when `recording_studio_api` is loaded and `:operations` is configured. They appear as Admin MCP tools. Update advertises `name` in its input contract.
- `RecordingStudioSiteSettings::Api` (`registration`, `access`, `show`, `update`, `serialize`). Access matches the Site admin screen: role on the access recording, which must be the `site_admin_recording`; site root from `site_root_resolver` with a nil controller; update keeps `Store.authorize_write!`.
- `RecordingStudioSiteSettings::Admin::MARK_VARIANTS`, the preview variant per image slot. The settings screen and the API both use it.

### Changed
- Root and dummy pin `recording_studio_metrics` `v0.2.3` (needed by `recording_studio_api`). Dummy bundles `recording_studio_api` `v0.7.0` with its migrations; `AdminRoot` is an API access point and `RecordingStudioApi::ApiClient` is an access actor type in dummy.

### Upgrade notes
- No runtime dependency added. Hosts without `recording_studio_api` see no change.
- Hosts with a custom `site_root_resolver` that only reads the controller should also return a site root when `context.controller` is nil, or the API answers 404.

## [0.2.0] - 2026-10-13

### Changed
- Dummy and README GitHub tags now track Accessible `v0.11.1`, Admin `v2.0.4`, Attachable `v0.7.1`, and Root Switchable `v0.5.3`. Core stays on `v4.2.2`.
- Gemspec floors: Accessible `~> 0.11`. Attachable stays `~> 0.5` (already accepts `0.7`). Admin stays `~> 2.0`.
- Dummy Accessible schema includes 0.8–0.11 migrations: `depends_on_recording_id`, access invitations, and string roles.

### Upgrade notes
- Pin Accessible `~> 0.11`. Root and README GitHub tags track Attachable `v0.7.1`; dummy keeps Attachable `v0.5.0` because `recording_studio_user` `v0.6.2` still requires `recording_studio_attachable ~> 0.5.0`.
- Hosts already on Accessible 0.8+ should run `bin/rails generate recording_studio_accessible:migrations` then `bin/rails db:migrate` so roles are strings and invitations exist.
- Grant access through `bootstrap_owner_access!` / `grant_access`. Do not write `RecordingStudio::Access` rows directly.

### Added
- English Rails I18n keys for the Site Settings save notice and invalid-name alert under `recording_studio.site_settings.flashes.*` (`config/locales/en.yml`), resolved through `RecordingStudioSiteSettings::Copy.t` with no English `default:` fallback.
- English Rails I18n keys for public logo helper alt fallbacks under `recording_studio.site_settings.helpers.*` (`square_logo_alt` / `wide_logo_alt`), resolved through `Copy.t` with no English `default:` fallback.
- Host English override coverage: test-only fixture `test/dummy/test/locales/site_settings_host_override.en.yml` loaded into a fresh `I18n::Backend::Simple` via `load_translations` (no `I18n.load_path` mutation) plus real-page asserts after save redirect and invalid-name re-render (flashes and helper alts).
- Always-loaded boot-order guard `test/dummy/config/locales/recording_studio_site_settings_boot_override.en.yml` for the real, rarely shown public helper alt keys, asserted on the real blank-name settings screen via `recording_studio_site_wide_logo` (visible flashes stay main English when the site is named; no probe keys, probe routes, or probe controllers).
- Locale regression: French flash notice via stored translations; English render stays byte-identical to main.

### Upgrade notes
- English hosts need no change. Copy `recording_studio.site_settings.flashes.saved`, `flashes.check_name`, `helpers.square_logo_alt`, and `helpers.wide_logo_alt` into host locale files when translating.
- Admin DSL title, subtitle, link, and action texts stay main's literal English Strings.

## [0.1.0] - 2026-09-02

### Added
- Site name, square logo, wide logo, and optional favicon as this gem's source of truth. One set per site root.
- Public read API: `name_for`, `square_logo_for`, `wide_logo_for`, `logo_for`, `favicon_for`, `recording_studio_site_square_logo`, `recording_studio_site_wide_logo`, `recording_studio_site_logo`, and `recording_studio_site_favicon`.
- Public write API: `update!`, gated with Accessible `:edit` on the site root. `square_logo_io` and `wide_logo_io` attach the marks. `logo_io` writes the square slot. `favicon_io` attaches the tab icon.
- Logo and favicon storage through three Attachable image children on this gem's site-settings recording, not on the root, named `square_logo`, `wide_logo`, and `favicon`.
- One Admin section and one screen for staff to edit name, both logos, and the tab icon.
- Dummy host that seeds a named Admin site with both logos, a named empty-mark Empty Admin root, Studio and Client Studio workspaces without site settings, and a 403 actor. Dummy sets `site_root_types` to `AdminRoot`. The gem default for hosts stays `Workspace`. Dummy layout head prints the favicon link tag from the Admin site root. Dummy home and dummy docs print the wide logo in a Flatpack Sidebar from that same Admin site root. Dummy does not override core `default_layout`.

### Changed
- Admin PageNav is the back control only. The visible title is PageTitle once.
- Admin form spacing comes from Flatpack Grid. Fields stack in this order: site name, wide logo, square logo, favicon. Save and Cancel are separate Buttons after the fields.
- Mark rows stack full width. Square logo uses Attachable's file button and a square Avatar. Wide logo uses the same button and the image in real proportion. Empty Avatars pass Flatpack `icon: "photo"`. Name save is a separate form. The page does not use Flatpack FileInput.
- `SiteSetting` allowed parents follow live `site_root_types`. Dummy parents site settings on `AdminRoot` so Accessible `:edit` on that root covers writes. Hosts still default to `Workspace`.
- Dummy and the README GitHub tag track Accessible `v0.9.0`. The gemspec floor stays `~> 0.8`.
- Dummy Tailwind writes resolved gem `@source` paths before each build so core PageNav back keeps its Flatpack icon size.
- Flatpack floor is `>= 0.1.144` so empty Avatars can pass `icon: "photo"`.

### Upgrade notes
- Add `recording_studio_site_settings` `~> 0.1`.
- Pin `recording_studio ~> 4.2`, Accessible `~> 0.8`, Admin `~> 2.0`, Attachable `~> 0.5`, and Flatpack `>= 0.1.144`.
- Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`.
- Do not add name, logo, or favicon columns to core or to the root recordable.
- Read name, logos, and favicon from this gem. Do not read Attachable to print a site mark.
- Print the square mark with `recording_studio_site_square_logo` or `recording_studio_site_logo`. Print the wide mark with `recording_studio_site_wide_logo`. Print the tab icon with `recording_studio_site_favicon`. Do not depend on Attachable from other gems just for those marks.
- Set `site_root_types` in the initializer. Do not add a YAML settings file.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_site_settings/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_site_settings/compare/v0.1.11...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_site_settings/releases/tag/v0.1.0
