# frozen_string_literal: true

require "test_helper"

class LogoTest < Minitest::Test
  def test_present_when_recording_exists
    logo = RecordingStudioSiteSettings::Logo.new(Object.new, "/preview", "mark.png")

    assert_predicate logo, :present?
    refute_predicate logo, :blank?
    assert_equal "/preview", logo.preview_url
    assert_equal "mark.png", logo.filename
  end

  def test_blank_without_a_recording
    logo = RecordingStudioSiteSettings::Logo.new(nil, nil, nil)

    assert_predicate logo, :blank?
    refute_predicate logo, :present?
  end
end
