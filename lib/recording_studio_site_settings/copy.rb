# frozen_string_literal: true

require "i18n"

module RecordingStudioSiteSettings
  # Rails I18n lookups for Site Settings user-facing copy. English ships only
  # in `config/locales/en.yml`. Missing keys behave like plain `I18n.t`
  # (translation missing / raise-on-missing) — no English `default:` fallback.
  # Keys live under `recording_studio.site_settings.*`.
  module Copy
    PREFIX = "recording_studio.site_settings"

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end
  end
end
