# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    # ActiveRecord::RecordInvalid is left to the API controller, which renders it as 422.
    # Logos are downloaded only after the caller passes the same checks as a name change, and all of
    # them are downloaded and checked before anything is saved. Saving goes through Store.update!,
    # the same path the Site screen uses.
    class Update
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        root = Access.write(context)
        actor = Access.actor_for(context)
        RecordingStudioSiteSettings::Store.authorize_write!(root, actor)
        input = UpdateInput.parse!(context&.params)
        RecordingStudioSiteSettings.update!(root, name: name_for(input, root), actor: actor, clear: input.clears,
                                                  **downloaded_files(input.sources))
        Serialize.site_settings(root)
      rescue RecordingStudioSiteSettings::Unauthorized => e
        raise RecordingStudioApi::AuthorizationError, e.message
      end

      private

      attr_reader :context

      def name_for(input, root)
        input.name_given? ? input.name : Store.name_for(root)
      end

      def downloaded_files(sources)
        errors = []
        files = sources.each_with_object({}) do |(slot, url), output|
          output.merge!(file_args(slot, RemoteImage.fetch(url, max_bytes: max_bytes)))
        rescue RemoteImage::Error => e
          errors << "#{UpdateInput.file_field(slot)} #{e.message}"
        end
        raise_logo_errors!(errors) if errors.any?

        files
      end

      def raise_logo_errors!(errors)
        raise RecordingStudioApi::InvalidActionInputError.new("Logo could not be used: #{errors.join('; ')}",
                                                              details: errors)
      end

      # Keys Store.update! reads for a slot, as in Store::IMAGE_SLOTS.
      def file_args(slot, download)
        {
          "#{slot}_io": download.io,
          "#{slot}_filename": "#{slot}.#{download.extension}",
          "#{slot}_content_type": download.content_type
        }
      end

      # Same limit as the Site screen's file buttons: SiteSetting's Attachable option, else Attachable's.
      def max_bytes
        @max_bytes ||= begin
          options = RecordingStudio.capability_options(:attachable, for_type: RECORDABLE_TYPE) || {}
          options.fetch(:max_file_size) { RecordingStudioAttachable.configuration.max_file_size } ||
            RemoteImage::DEFAULT_MAX_BYTES
        end
      end
    end
  end
end
