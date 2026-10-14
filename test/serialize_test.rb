# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SerializeTest < Minitest::Test
  Serialize = RecordingStudioSiteSettings::Api::Serialize
  PATH = "/recording_studio_attachable/attachments/abc/preview/square_med"

  def teardown
    RecordingStudioSiteSettings.configuration.public_url_options = nil
  end

  def test_preview_paths_become_absolute_from_the_current_request
    url = Serialize.stub(:routes_default_url_options, {}) do
      RecordingStudioSiteSettings::RequestBaseUrl.with("https://tunnel.example.dev") { Serialize.absolute_url(PATH) }
    end

    assert_equal "https://tunnel.example.dev#{PATH}", url
  end

  def test_routes_default_url_options_win_over_the_request
    url = Serialize.stub(:routes_default_url_options, { host: "app.example.com", protocol: "https" }) do
      RecordingStudioSiteSettings::RequestBaseUrl.with("http://internal:3000") { Serialize.absolute_url(PATH) }
    end

    assert_equal "https://app.example.com#{PATH}", url
  end

  def test_configured_public_url_options_win_and_keep_a_non_default_port
    RecordingStudioSiteSettings.configuration.public_url_options = { host: "localhost", protocol: "http", port: 3000 }

    url = Serialize.stub(:routes_default_url_options, { host: "app.example.com" }) { Serialize.absolute_url(PATH) }

    assert_equal "http://localhost:3000#{PATH}", url
  end

  def test_without_any_base_the_path_and_nil_pass_through
    Serialize.stub(:routes_default_url_options, nil) do
      assert_equal PATH, Serialize.absolute_url(PATH)
      assert_nil Serialize.absolute_url(nil)
      assert_equal "https://cdn.example.com/x", Serialize.absolute_url("https://cdn.example.com/x")
    end
  end

  def test_request_base_url_middleware_sets_and_clears_the_base
    seen = nil
    app = lambda do |_env|
      seen = RecordingStudioSiteSettings::RequestBaseUrl.current
      [200, {}, []]
    end
    env = Rack::MockRequest.env_for("https://tunnel.example.dev/mcp")

    RecordingStudioSiteSettings::RequestBaseUrl.new(app).call(env)

    assert_equal "https://tunnel.example.dev", seen
    assert_nil RecordingStudioSiteSettings::RequestBaseUrl.current
  end
end
