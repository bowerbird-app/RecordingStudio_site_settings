# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-02

### Added
- Site name, site logo, and optional favicon as this gem's source of truth. One set per site root.
- Public read API: `name_for`, `logo_for`, `favicon_for`, `recording_studio_site_logo`, and `recording_studio_site_favicon`.
- Public write API: `update!`, gated with Accessible `:edit` on the site root. `favicon_io` attaches the tab icon.
- Logo and favicon storage through two Attachable image children on this gem's site-settings recording, not on the root.
- One Admin section and one screen for staff to edit name, logo, and tab icon.
- Dummy host that seeds a named logo site, a named empty-logo site, and a 403 actor. Dummy layout may print the favicon link tag.

### Changed
- Admin PageNav is the back control only. The visible title is PageTitle once.
- Admin form spacing comes from Flatpack Grid. Save stays primary. Cancel is a separate back control.
- Logo and favicon rows stack full width. Each uses Attachable's file button and a square Avatar preview. Name save is a separate form. The page does not use Flatpack FileInput.
- Hosts set `site_root_types` in the initializer. There is no site-settings YAML file.
- Dummy and the README GitHub tag track Accessible `v0.9.0`. The gemspec floor stays `~> 0.8`.
- Dummy Tailwind writes resolved gem `@source` paths before each build so core PageNav back keeps its Flatpack icon size.

### Upgrade notes
- Add `recording_studio_site_settings` `~> 0.1`.
- Pin `recording_studio ~> 4.2`, Accessible `~> 0.8`, Admin `~> 2.0`, and Attachable `~> 0.5`.
- Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`.
- Do not add name, logo, or favicon columns to core or to the root recordable.
- Read name, logo, and favicon from this gem. Do not read Attachable to print a site mark.
- Print the tab icon with `recording_studio_site_favicon`. Do not depend on Attachable from other gems just for that link.
- Set `site_root_types` in the initializer. Do not add a YAML settings file.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_site_settings/releases/tag/v0.1.0
