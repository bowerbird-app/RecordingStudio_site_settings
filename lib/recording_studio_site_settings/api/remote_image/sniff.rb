# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Api
    class RemoteImage
      # Image type from the file's first bytes. Headers and file names are not trusted.
      module Sniff
        PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
        JPEG_SIGNATURE = "\xFF\xD8\xFF".b
        SVG_PATTERN = /\A(?:\xEF\xBB\xBF)?\s*(?:<\?xml|<svg|<!--|<!DOCTYPE\s+svg)/ni

        module_function

        # [content_type, extension] for PNG, JPEG, or WebP; nil for anything else.
        def type_for(bytes)
          return %w[image/png png] if bytes.start_with?(PNG_SIGNATURE)
          return %w[image/jpeg jpg] if bytes.start_with?(JPEG_SIGNATURE)

          %w[image/webp webp] if bytes.byteslice(0, 4) == "RIFF" && bytes.byteslice(8, 4) == "WEBP"
        end

        def svg?(bytes)
          bytes.match?(SVG_PATTERN)
        end
      end
    end
  end
end
