# frozen_string_literal: true

module RecordingStudioSiteSettings
  RECORDABLE_TYPE = "RecordingStudioSiteSettings::SiteSetting"

  module Store # rubocop:disable Metrics/ModuleLength
    module_function

    def name_for(root_recording)
      settings_for(root_recording)&.name
    end

    LOGO_SLOT = "logo"
    FAVICON_SLOT = "favicon"

    def logo_for(root_recording, variant: :square_med)
      mark_for(logo_recording_for(root_recording), variant: variant)
    end

    def favicon_for(root_recording, variant: :square_small)
      mark_for(favicon_recording_for(root_recording), variant: variant)
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
      parent = recording_for(root_recording)
      named_image(parent, LOGO_SLOT) || unmarked_logo_image(parent)
    end

    def favicon_recording_for(root_recording)
      named_image(recording_for(root_recording), FAVICON_SLOT)
    end

    def update!(root_recording, name:, actor:, **file)
      authorize_write!(root_recording, actor)
      recording = ensure_recording!(root_recording, name: name, actor: actor)
      revise_name!(recording, name: name, actor: actor)
      attach_named_image!(recording, actor: actor, slot: LOGO_SLOT, **logo_file_args(file)) if file[:logo_io]
      attach_named_image!(recording, actor: actor, slot: FAVICON_SLOT, **favicon_file_args(file)) if file[:favicon_io]
      recording.reload
    end

    def attach_named_image!(parent_recording, actor:, slot:, **file)
      existing = existing_image_for(parent_recording, slot)
      return replace_image!(existing, actor:, **file) if existing.present?

      import_image!(parent_recording, actor:, slot:, **file)
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
      allowed = RecordingStudioAccessible.authorized?(actor:, recording: root_recording, role: :edit)
      raise Unauthorized, "You cannot change this site's name, logo, or tab icon." unless allowed
    end

    def ensure_recording!(root_recording, name:, actor:)
      existing = recording_for(root_recording)
      return existing if existing.present?

      with_actor(actor) { root_recording.record(SiteSetting, actor: actor) { |settings| settings.name = name } }
    end

    def revise_name!(recording, name:, actor:)
      return recording if recording.recordable&.name == name

      with_actor(actor) do
        recording.root_recording.revise(recording, actor: actor) { |settings| settings.name = name }
      end
    end

    def replace_image!(existing, actor:, **file)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: file.fetch(:io),
        filename: file.fetch(:filename),
        content_type: file.fetch(:content_type)
      )
      existing.replace_attachment_file(signed_blob_id: blob.signed_id, actor: actor)
    end

    def import_image!(parent_recording, actor:, slot:, **file)
      result = RecordingStudioAttachable::Services::ImportAttachment.call(
        parent_recording: parent_recording,
        io: file.fetch(:io),
        filename: file.fetch(:filename),
        content_type: file.fetch(:content_type),
        actor: actor,
        name: slot
      )
      raise result.error if result.failure?

      result.value
    end

    def mark_for(attachment, variant:)
      Logo.new(attachment, preview_url_for(attachment, variant), filename_for(attachment))
    end

    def images_for(parent_recording)
      return [] if parent_recording.blank? || !parent_recording.respond_to?(:images)

      Array(parent_recording.images(per_page: 24))
    end

    def named_image(parent_recording, slot)
      images_for(parent_recording).find { |recording| image_slot_name(recording).casecmp?(slot) }
    end

    def unmarked_logo_image(parent_recording)
      images_for(parent_recording).find { |recording| !image_slot_name(recording).casecmp?(FAVICON_SLOT) }
    end

    def existing_image_for(parent_recording, slot)
      return named_image(parent_recording, slot) if slot == FAVICON_SLOT

      named_image(parent_recording, LOGO_SLOT) || unmarked_logo_image(parent_recording)
    end

    def image_slot_name(recording)
      recording.recordable&.name.to_s
    end

    def logo_file_args(file)
      {
        io: file[:logo_io],
        filename: file[:filename],
        content_type: file[:content_type]
      }
    end

    def favicon_file_args(file)
      {
        io: file[:favicon_io],
        filename: file[:favicon_filename].presence || file[:filename],
        content_type: file[:favicon_content_type].presence || file[:content_type]
      }
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

    def with_actor(actor)
      previous_actor = Current.actor if defined?(Current)
      Current.actor = actor if defined?(Current)
      yield
    ensure
      Current.actor = previous_actor if defined?(Current)
    end
  end
end
