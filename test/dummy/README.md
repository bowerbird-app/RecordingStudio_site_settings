# Dummy app

This Rails app is a host that proves `recording_studio_site_settings`.

It is not the product. The product is the gem README and the admin screen for name, logo, and tab icon.

## Sign in

- Email: `admin@admin.com`
- Password: `Password`

`member@admin.com` / `Password` has no admin grant and gets 403 on the site settings screen.

## Routes that matter

- `/users/sign_in`
- `/recording_studio_site_settings/settings` — the site name, logo, and favicon admin screen
- `/admin` — Admin mount with the Site section

Seeded Studio has a name and a logo. Seeded Client Studio has a name and no logo. Neither seed has a favicon. The admin mark rows are an Avatar plus Attachable's Add or Change button, not a dropzone. Empty logo and favicon Avatars show a photo icon. The dummy layout may print `recording_studio_site_favicon`.
