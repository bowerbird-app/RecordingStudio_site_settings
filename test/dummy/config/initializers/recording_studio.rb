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

  # Recording Studio 6.5 denies writes unless an authorizer is set. This dummy
  # still records from seeds and tests that do not pass an actor.
  config.allow_unauthorized_writes = true

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
