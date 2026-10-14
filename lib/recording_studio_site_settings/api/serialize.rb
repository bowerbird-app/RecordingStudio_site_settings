# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    module Serialize
      module_function

      def site_settings(root)
        { name: Store.name_for(root) }.merge(marks(root))
      end

      def marks(root)
        RecordingStudioSiteSettings::Admin::MARK_VARIANTS.to_h do |slot, variant|
          [slot.to_sym, mark(Store.public_send(:"#{slot}_for", root, variant: variant), variant)]
        end
      end

      def mark(logo, variant)
        {
          present: logo.present?,
          variant: variant.to_s,
          recording_id: logo.recording&.id,
          filename: logo.filename,
          preview_url: logo.preview_url
        }
      end
    end
  end
end
