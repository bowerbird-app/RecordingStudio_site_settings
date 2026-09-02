# frozen_string_literal: true

Rails.application.config.x.site_settings_importmap_roots = {
  admin: RecordingStudioAdmin::Engine.root,
  attachable: RecordingStudioAttachable::Engine.root
}
