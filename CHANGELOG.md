# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-02

### Added
- Site name and site logo as this gem's source of truth. One pair per site root.
- Public read API: `name_for`, `logo_for`, and `recording_studio_site_logo`.
- Public write API: `update!`, gated with Accessible `:edit` on the site root.
- Logo storage through Attachable on this gem's site-settings recording, not on the root.
- One Admin section and one screen for staff to edit name and logo.
- Dummy host that seeds a named logo site, a named empty-logo site, and a 403 actor.

### Changed
- Admin PageNav is the back control only. The visible title is PageTitle once.
- Admin form spacing comes from Flatpack Grid. Save stays primary. Cancel is a separate back control.
- Hosts set `site_root_types` in the initializer. There is no site-settings YAML file.

### Upgrade notes
- Add `recording_studio_site_settings` `~> 0.1`.
- Pin `recording_studio ~> 4.2`, Accessible `~> 0.8`, Admin `~> 2.0`, and Attachable `~> 0.5`.
- Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`.
- Do not add name or logo columns to core or to the root recordable.
- Read name and logo from this gem. Do not read Attachable to print the site mark.
- Set `site_root_types` in the initializer. Do not add a YAML settings file.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_site_settings/releases/tag/v0.1.0
