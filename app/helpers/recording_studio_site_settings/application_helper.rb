# frozen_string_literal: true

module RecordingStudioSiteSettings
  module ApplicationHelper
    def recording_studio_site_logo(root_recording, size: :xl, variant: :square_med, **system_args)
      logo = RecordingStudioSiteSettings.logo_for(root_recording, variant: variant)
      name = RecordingStudioSiteSettings.name_for(root_recording)
      src = logo_preview_src(logo, variant)

      render FlatPack::Avatar::Component.new(
        src: src,
        size: size,
        shape: :rounded,
        alt: name.presence || "Site logo",
        **system_args
      )
    end

    private

    def logo_preview_src(logo, variant)
      return if logo.blank?

      if respond_to?(:attachment_preview_url)
        attachment_preview_url(logo.recording, variant: variant)
      else
        logo.preview_url
      end
    end
  end
end
