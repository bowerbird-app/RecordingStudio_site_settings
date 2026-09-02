# Dummy app

This Rails app is a host that proves `recording_studio_site_settings`.

It is not the product. The product is the gem README and the admin screen for name, logos, and tab icon.

## Sign in

- Email: `admin@admin.com`
- Password: `Password`

`member@admin.com` / `Password` has no admin grant and gets 403 on the site settings screen.

## Routes that matter

- `/users/sign_in`
- `/recording_studio_site_settings/settings` — the site name, logos, and favicon admin screen
- `/admin` — Admin mount with the Site section

Seeded Studio has a name, a square logo, and a wide logo. Seeded Client Studio has a name and empty marks. Neither seed has a favicon. The admin mark rows are an Avatar or wide image plus Attachable's Add or Change button, not a dropzone. Empty square, wide, and favicon slots show a photo icon. Dummy home and dummy docs print the wide logo in a sidebar from `recording_studio_site_wide_logo`. Dummy does not override core `default_layout`. The dummy layout head may print `recording_studio_site_favicon`.
