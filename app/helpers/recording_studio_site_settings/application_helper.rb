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

    def recording_studio_site_favicon(root_recording, variant: :square_small)
      favicon = RecordingStudioSiteSettings.favicon_for(root_recording, variant: variant)
      return if favicon.blank? || favicon.preview_url.blank?

      tag.link(rel: "icon", href: favicon.preview_url)
    end

    def render_site_settings_file_button(parent_recording, slot:, return_to:)
      attachment = site_settings_slot_recording(parent_recording, slot)
      locals = RecordingStudioAttachable::AttachmentFileButton.locals(
        recording: parent_recording,
        return_to: return_to,
        target: "site-#{slot}"
      ).merge(attachment_recording: attachment, mark_name: slot.to_s)

      render partial: "recording_studio_site_settings/admin/settings/mark_file_button", locals: locals
    end

    private

    def site_settings_slot_recording(parent_recording, slot)
      root = parent_recording&.root_recording || parent_recording
      case slot.to_s
      when RecordingStudioSiteSettings::Store::LOGO_SLOT
        RecordingStudioSiteSettings.logo_recording_for(root)
      when RecordingStudioSiteSettings::Store::FAVICON_SLOT
        RecordingStudioSiteSettings.favicon_recording_for(root)
      end
    end
  end
end
