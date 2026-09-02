# frozen_string_literal: true

module RecordingStudioSiteSettings
  module ApplicationHelper
    def recording_studio_site_logo(root_recording, size: :xl, variant: :square_med, **system_args)
      logo = RecordingStudioSiteSettings.logo_for(root_recording, variant: variant)
      name = RecordingStudioSiteSettings.name_for(root_recording)

      render FlatPack::Avatar::Component.new(
        src: logo.preview_url,
        size: size,
        shape: :rounded,
        alt: name.presence || "Site logo",
        **system_args
      )
    end
  end
end
