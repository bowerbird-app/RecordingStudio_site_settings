# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 4.2`
- Accessible `~> 0.8`
- Admin `~> 2.0`
- Attachable `~> 0.5`

## Host upgrade

1. Add the gem and pin the majors above.
2. Run the install and migrations generators.
3. Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`.
4. Set `site_root_types` in the initializer to the host site root class, usually `Workspace`. Do not add a YAML settings file.
5. Enable the `site_settings` Admin section on the admin root and grant Accessible access there.

Name and logo stay in this gem. Do not copy them onto the root.
