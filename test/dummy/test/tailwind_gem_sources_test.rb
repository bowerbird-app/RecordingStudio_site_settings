# frozen_string_literal: true

require "test_helper"

class TailwindGemSourcesTest < ActiveSupport::TestCase
  test "resolved sources include Flatpack components" do
    sources = Dummy::TailwindGemSources.source_directories
    flatpack = sources.find { |path| path.include?("flatpack") && path.end_with?("app/components") }

    refute_nil flatpack
    assert File.directory?(flatpack)
    assert_includes Dummy::TailwindGemSources.css, %(@source "#{flatpack}";)
  end

  test "compiled tailwind includes PageNav icon size classes" do
    css_path = Rails.root.join("app/assets/builds/tailwind.css")
    assert css_path.exist?, "run bin/rails tailwindcss:build in test/dummy"
    css = css_path.read

    assert_includes css, "button-icon-only-padding-md"
    assert_match(/\.w-5\s*\{/, css)
  end
end
