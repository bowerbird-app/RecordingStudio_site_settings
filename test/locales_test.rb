# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  EXPECTED_KEYS = {
    "flashes.saved" => "Saved. That's this site's name, logos, and tab icon.",
    "flashes.check_name" => "Check the name and try again.",
    "probes.boot_override" => "Site settings boot override probe."
  }.freeze

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_english_keys_match_main_literals
    with_isolated_backend do
      EXPECTED_KEYS.each do |key, english|
        assert_equal english, RecordingStudioSiteSettings::Copy.t(key),
                     "Copy.t(#{key.inspect}) must return main English from en.yml"
        assert_equal english, I18n.t("recording_studio.site_settings.#{key}"),
                     "I18n key recording_studio.site_settings.#{key} must match main English"
      end
    end
  end

  def test_copy_missing_key_does_not_silently_return_english
    with_isolated_backend(load_gem_english: false) do
      missing = RecordingStudioSiteSettings::Copy.t("flashes.saved")

      refute_equal "Saved. That's this site's name, logos, and tab icon.", missing
      assert_match(/translation missing/i, missing.to_s)
    end
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_dir = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_dir, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_call_sites_do_not_pass_english_default
    roots = [
      File.expand_path("../app", __dir__),
      File.expand_path("../lib", __dir__)
    ]
    ruby_files = roots.flat_map { |root| Dir[File.join(root, "**", "*.rb")] }

    ruby_files.each do |path|
      source = File.read(path)
      next unless source.match?(/\bCopy\.t\b/)

      source.scan(/Copy\.t\([^)]*\)/m).each do |call|
        refute_match(/\bdefault:\s*["']/, call,
                     "#{path} must not pass English default: to Copy.t (#{call})")
      end
    end
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
  end

  def test_controller_flashes_use_copy_t_not_english_literals
    path = File.expand_path(
      "../app/controllers/recording_studio_site_settings/admin/settings_controller.rb",
      __dir__
    )
    source = File.read(path)

    assert_includes source, 'Copy.t("flashes.saved")'
    assert_includes source, 'Copy.t("flashes.check_name")'
    refute_match(/notice:\s*"Saved\./, source,
                 "reverting the save flash to a literal must fail this test")
    refute_match(/flash\.now\[:alert\]\s*=\s*"Check the name/, source,
                 "reverting the invalid-name flash to a literal must fail this test")
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def with_isolated_backend(load_gem_english: true)
    previous_backend = I18n.backend
    previous_load_path = I18n.load_path.dup
    previous_available = I18n.available_locales
    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = []
    I18n.available_locales = [:en]
    if load_gem_english
      path = File.join(engine_locales_dir, "en.yml")
      I18n.backend.store_translations(:en, YAML.safe_load_file(path, aliases: true).fetch("en"))
    else
      I18n.backend.store_translations(:en, {})
    end
    yield
  ensure
    I18n.backend = previous_backend
    I18n.load_path = previous_load_path
    I18n.available_locales = previous_available
  end
end
