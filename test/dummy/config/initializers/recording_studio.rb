# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "AdminRoot",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment"
  ]

  config.require_recordable_declarations = true

  config.app_name = "Site settings dummy" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  # Core 7 denies a write until this callback allows it.
  config.authorize_write = ->(**) { true }

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
