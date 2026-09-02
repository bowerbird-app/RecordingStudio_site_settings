# Recording Studio Site Settings

This gem holds one site name, a square logo, a wide logo, and one optional favicon per site root.

- Public API: `name_for`, `square_logo_for`, `wide_logo_for`, `logo_for`, `favicon_for`, `recording_studio_site_square_logo`, `recording_studio_site_wide_logo`, `recording_studio_site_logo`, `recording_studio_site_favicon`, `update!`
- Logo and favicon storage is three Attachable children on this gem's site-settings recording, not on the root
- Admin: one Site section and one screen, gated with Accessible on the admin root
- Pins: Recording Studio `~> 4.2`, Accessible `~> 0.8` (dummy and README GitHub tag `v0.9.0`), Admin `~> 2.0`, Attachable `~> 0.5`, Flatpack `>= 0.1.144`
