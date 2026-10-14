# frozen_string_literal: true

require "test_helper"

class RequestBaseUrlTest < ActiveSupport::TestCase
  PATH = "/rails/active_storage/blobs/x/logo.png"

  def env
    Rack::MockRequest.env_for("https://demo.example.test/recording_studio_mcp")
  end

  def absolute(path) = RecordingStudioSiteSettings::Api::Serialize.absolute_url(path)

  test "eager bodies get the request host" do
    app = RecordingStudioSiteSettings::RequestBaseUrl.new(->(_e) { [200, {}, [absolute(PATH)]] })
    _, _, body = app.call(env)
    out = +""
    body.each { |c| out << c } # servers iterate with #each
    assert_equal "https://demo.example.test#{PATH}", out
  end

  test "streamed bodies built during iteration still get the request host" do
    lazy = Enumerator.new { |y| y << absolute(PATH) }
    app = RecordingStudioSiteSettings::RequestBaseUrl.new(->(_e) { [200, {}, lazy] })
    _, _, body = app.call(env)
    out = +""
    body.each { |c| out << c } # servers iterate with #each
    assert_equal "https://demo.example.test#{PATH}", out
    assert_nil RecordingStudioSiteSettings::RequestBaseUrl.current
  end

  test "close is forwarded" do
    closed = false
    inner = Object.new
    inner.define_singleton_method(:each) { |&_b| nil }
    inner.define_singleton_method(:close) { closed = true }
    _, _, body = RecordingStudioSiteSettings::RequestBaseUrl.new(->(_e) { [200, {}, inner] }).call(env)
    body.close
    assert closed
    refute body.respond_to?(:call)
  end
end
