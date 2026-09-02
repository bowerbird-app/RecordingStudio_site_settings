# Recording Studio Site Settings

This gem holds one site name and one site logo per site root.

- Public API: `name_for`, `logo_for`, `recording_studio_site_logo`, `update!`
- Logo storage is Attachable on this gem's site-settings recording, not on the root
- Admin: one Site section and one screen, gated with Accessible on the admin root
- Pins: Recording Studio `~> 4.2`, Accessible `~> 0.8` (dummy and README GitHub tag `v0.9.0`), Admin `~> 2.0`, Attachable `~> 0.5`
