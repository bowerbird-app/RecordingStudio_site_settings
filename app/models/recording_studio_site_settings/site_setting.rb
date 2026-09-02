# frozen_string_literal: true

module RecordingStudioSiteSettings
  class SiteSetting < ApplicationRecord
    self.table_name = "recording_studio_site_settings"

    recording_studio_recordable label: "Site settings",
                                root: false,
                                allowed_parent_types: RecordingStudioSiteSettings.configuration.site_root_types

    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: %i[image],
      max_file_count: 1
    )

    self.record_timestamps = false

    validates :name, presence: true

    before_create { self.created_at ||= Time.current }
  end
end
