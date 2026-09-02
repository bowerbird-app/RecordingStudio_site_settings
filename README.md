# Recording Studio Site Settings

This gem is the source of truth for a site's name and logo in Recording Studio.

Core does not store them. The site root does not store them. Other gems read them from this gem. Do not call Attachable just to print the mark.

Each site root gets one name and one logo. The logo is an Attachable image under this gem's site-settings recording.

## Install

Add the gem and its Recording Studio majors:

```ruby
gem "recording_studio_site_settings"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "2.0.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.0"
```

Then:

```bash
bin/rails generate recording_studio_site_settings:install
bin/rails generate recording_studio_site_settings:migrations
bin/rails generate recording_studio_attachable:install
bin/rails generate recording_studio_attachable:migrations
bin/rails db:migrate
```

Register this gem's type next to the host root and Attachable's attachment type:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment"
  ]
end
```

Tell the gem which recordable is a site root:

```ruby
RecordingStudioSiteSettings.configure do |config|
  config.site_root_types = ["Workspace"]
end
```

Enable Accessible on the site root and on the admin root. Enable Attachable only on `RecordingStudioSiteSettings::SiteSetting`. Do not enable Attachable on the root to hold the logo.

Mount the engines and Admin:

```ruby
mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
mount RecordingStudioSiteSettings::Engine, at: "/recording_studio_site_settings"
recording_studio_admin_for :admin, at: "/admin", root_section: :site_settings
```

Enable the `site_settings` section on the admin root. Grant Accessible access on that admin root. People without that grant get 403.

## Read name and logo

```ruby
root = RecordingStudio.root_recording_for(workspace)

RecordingStudioSiteSettings.name_for(root)
RecordingStudioSiteSettings.logo_for(root)
RecordingStudioSiteSettings.logo_for(root).preview_url
RecordingStudioSiteSettings.logo_for(root).present?
```

In a view:

```erb
<%= RecordingStudioSiteSettings.name_for(current_root_recording) %>
<%= recording_studio_site_logo(current_root_recording) %>
```

`logo_for` returns a small object with `recording`, `preview_url`, `filename`, `present?`, and `blank?`. Callers should not reach into Attachable to render the mark.

## Write name and logo

```ruby
RecordingStudioSiteSettings.update!(
  root,
  name: "Studio",
  actor: current_user,
  logo_io: File.open("logo.png"),
  filename: "logo.png",
  content_type: "image/png"
)
```

Writes check Accessible `:edit` on the site root. Name changes `revise` the site-settings recording. A second logo on the same site replaces the file on the existing attachment.

## Admin

Staff open one Admin section, Site, and one screen that edits name and logo. The screen uses Recording Studio core default layout. Call `recording_studio_page_nav` so PageNav back is on the page. Back is `history.back()`. The title lives once in PageTitle.

The logo row matches Users edit profile: a square Avatar preview and Attachable's file-only Add or Change button, outside the name form. Name has its own Save. Cancel goes back. Accessible on the admin root gates the page. `user.admin?` is not used.

## Dummy app

`test/dummy` is a host that proves this gem. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. The admin screen is `/recording_studio_site_settings/settings`.

Dummy Tailwind writes resolved engine `@source` paths to `gem_sources.css` before each build. Bundle globs miss Flatpack on some install paths, and without those component classes PageNav back collapses to 2px.

Seeded proof:

- Studio has the name Studio and a logo
- Client Studio has a name and no logo
- `member@admin.com` has no admin grant and gets 403
