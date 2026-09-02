# frozen_string_literal: true

module RecordingStudioSiteSettings
  RECORDABLE_TYPE = "RecordingStudioSiteSettings::SiteSetting"

  module Store
    module_function

    def name_for(root_recording)
      settings_for(root_recording)&.name
    end

    def logo_for(root_recording, variant: :square_med)
      attachment = logo_recording_for(root_recording)
      Logo.new(
        attachment,
        preview_url_for(attachment, variant),
        filename_for(attachment)
      )
    end

    def recording_for(root_recording)
      return if root_recording.blank?

      RecordingStudio::Recording.find_by(
        root_recording_id: root_recording.id,
        parent_recording_id: root_recording.id,
        recordable_type: RECORDABLE_TYPE,
        trashed_at: nil
      )
    end

    def settings_for(root_recording)
      recording_for(root_recording)&.recordable
    end

    def logo_recording_for(root_recording)
      recording = recording_for(root_recording)
      return if recording.blank?
      return unless recording.respond_to?(:images)

      recording.images(per_page: 1).first
    end

    def update!(root_recording, name:, actor:, logo_io: nil, filename: nil, content_type: nil)
      authorize_write!(root_recording, actor)
      recording = ensure_recording!(root_recording, name: name, actor: actor)
      revise_name!(recording, name: name, actor: actor)
      attach_logo!(recording, io: logo_io, filename: filename, content_type: content_type, actor: actor) if logo_io
      recording.reload
    end

    def attach_logo!(parent_recording, io:, filename:, content_type:, actor:)
      existing = parent_recording.images(per_page: 1).first if parent_recording.respond_to?(:images)
      return replace_logo!(existing, io:, filename:, content_type:, actor:) if existing.present?

      result = RecordingStudioAttachable::Services::ImportAttachment.call(
        parent_recording: parent_recording,
        io: io,
        filename: filename,
        content_type: content_type,
        actor: actor,
        name: File.basename(filename.to_s, File.extname(filename.to_s))
      )
      raise result.error if result.failure?

      result.value
    end

    def ensure_recording!(root_recording, name:, actor:)
      existing = recording_for(root_recording)
      return existing if existing.present?

      previous_actor = Current.actor if defined?(Current)
      Current.actor = actor if defined?(Current)
      root_recording.record(SiteSetting, actor: actor) { |settings| settings.name = name }
    ensure
      Current.actor = previous_actor if defined?(Current)
    end

    def site_root?(recording)
      return false if recording.blank?

      type_name = RecordingStudio.recordable_type_name(recording.recordable)
      Array(RecordingStudioSiteSettings.configuration.site_root_types).include?(type_name)
    end

    def site_root_for(context)
      RecordingStudioSiteSettings.configuration.site_root_resolver.call(context)
    end

    def authorize_write!(root_recording, actor)
      allowed = RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: root_recording,
        role: :edit
      )
      raise Unauthorized, "You cannot change this site's name or logo." unless allowed
    end

    def revise_name!(recording, name:, actor:)
      current_name = recording.recordable&.name
      return recording if current_name == name

      previous_actor = Current.actor if defined?(Current)
      Current.actor = actor if defined?(Current)
      recording.root_recording.revise(recording, actor: actor) { |settings| settings.name = name }
    ensure
      Current.actor = previous_actor if defined?(Current)
    end

    def replace_logo!(existing, io:, filename:, content_type:, actor:)
      blob = ActiveStorage::Blob.create_and_upload!(io:, filename:, content_type:)
      existing.replace_attachment_file(signed_blob_id: blob.signed_id, actor: actor)
    end

    def preview_url_for(attachment_recording, variant)
      return if attachment_recording.blank?

      RecordingStudioAttachable::Engine.routes.url_helpers.attachment_preview_file_path(
        attachment_recording,
        variant_name: variant
      )
    rescue StandardError
      nil
    end

    def filename_for(attachment_recording)
      attachment_recording&.recordable&.original_filename
    end
  end
end
