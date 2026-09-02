# Project Guidelines

## Architecture

- This repository is the Recording Studio Site Settings addon. It is the source of truth for a site's name, logo, and tab icon.
- Preserve engine namespace isolation under `RecordingStudioSiteSettings`.
- Treat `docs/gem_template/` as architectural reference material. The public README is the product.
- Do not store name, logo, or favicon on Recording Studio core or on the site root recordable.

## UI Conventions

- FlatPack is the default UI system for this repo.
- The approved UI reference is the live FlatPack demo app at https://flatpack.bowerbird.io/ when you need to inspect current shared components and patterns.
- When editing ERB views, prefer `render FlatPack::...` components over custom markup when an equivalent component exists.
- Dummy screens use `data-theme="rounded"` and Recording Studio core's `default_layout`.

## Testing

- The standard root validation command is `bundle exec rake test` from the repository root.
- Dummy-app tests live under `test/dummy/test/` and run via `bundle exec rake test:dummy`.
- Cover persistence in this gem, the Accessible admin gate, and the admin update path.
