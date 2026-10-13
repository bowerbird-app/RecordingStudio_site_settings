# frozen_string_literal: true

require "test_helper"
require "i18n"

class CopyTest < Minitest::Test
  def test_copy_missing_key_behaves_like_plain_i18n
    previous = I18n.backend
    previous_available = I18n.available_locales
    I18n.backend = I18n::Backend::Simple.new
    I18n.available_locales = [:en]
    I18n.backend.store_translations(:en, {})

    missing = RecordingStudioSiteSettings::Copy.t("flashes.saved")
    assert_match(/translation missing/i, missing.to_s)

    assert_raises(I18n::MissingTranslationData) do
      RecordingStudioSiteSettings::Copy.t("flashes.saved", raise: true)
    end
  ensure
    I18n.backend = previous
    I18n.available_locales = previous_available
  end

  def test_copy_reads_stored_translations
    previous = I18n.backend
    previous_available = I18n.available_locales
    I18n.backend = I18n::Backend::Simple.new
    I18n.available_locales = [:en]
    I18n.backend.store_translations(
      :en,
      recording_studio: {
        site_settings: {
          flashes: {
            check_name: "Check the name and try again."
          }
        }
      }
    )

    assert_equal "Check the name and try again.",
                 RecordingStudioSiteSettings::Copy.t("flashes.check_name")
  ensure
    I18n.backend = previous
    I18n.available_locales = previous_available
  end
end
