# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 4.2`
- Accessible `~> 0.8`
- Admin `~> 2.0`
- Attachable `~> 0.5`
- Flatpack `>= 0.1.144`

## Host upgrade

1. Add the gem and pin the majors above.
2. Run the install and migrations generators.
3. Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`.
4. Set `site_root_types` in the initializer to the host site root class, usually `Workspace`. Do not add a YAML settings file.
5. Enable the `site_settings` Admin section on the admin root and grant Accessible access there.

Name, logos, and favicon stay in this gem. Do not copy them onto the root.

The admin mark controls are Attachable file buttons on this gem's site-settings recording. Square logo, wide logo, and favicon are three named children (`square_logo`, `wide_logo`, and `favicon`). Hosts should not add a FileInput for a mark. Programmatic writes still go through `update!`. Print the square mark with `recording_studio_site_square_logo` or `recording_studio_site_logo`. Print the wide mark with `recording_studio_site_wide_logo`. Print the tab icon with `recording_studio_site_favicon`.
