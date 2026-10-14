# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class RemoteImageTest < Minitest::Test
  RemoteImage = RecordingStudioSiteSettings::Api::RemoteImage
  PNG = "#{"\x89PNG\r\n\x1A\n".b}rest-of-png".b
  JPEG = "#{"\xFF\xD8\xFF\xE0".b}jfif".b
  WEBP = "RIFF\x00\x00\x00\x00WEBPVP8 ".b

  FakeResponse = Struct.new(:code, :headers, :chunks) do
    def [](name)
      headers[name.downcase]
    end

    def read_body(&)
      chunks.each(&)
    end
  end

  class FakeTransport
    attr_reader :calls

    def initialize(responses)
      @responses = responses
      @calls = []
    end

    def get(uri, address:)
      @calls << [uri.to_s, address]
      yield @responses.fetch(uri.to_s)
    end
  end

  def test_downloads_a_png_from_a_public_host_and_pins_the_checked_address
    transport = FakeTransport.new("https://cdn.example.com/logo" => ok(PNG))

    download = fetch("https://cdn.example.com/logo", transport: transport)

    assert_equal "image/png", download.content_type
    assert_equal "png", download.extension
    assert_equal PNG, download.io.read
    assert_equal [["https://cdn.example.com/logo", "93.184.216.34"]], transport.calls
  end

  def test_sniffs_jpeg_and_webp_from_the_bytes
    assert_equal "image/jpeg", fetch_body(JPEG).content_type
    assert_equal "image/webp", fetch_body(WEBP).content_type
  end

  def test_ignores_a_content_type_header_that_lies
    response = ok("<html>not an image</html>", "content-type" => "image/png")

    error = assert_fetch_error(transport: FakeTransport.new("https://cdn.example.com/logo" => response))

    assert_equal "is not a PNG, JPEG, or WebP image", error.message
  end

  def test_rejects_gif_and_svg
    assert_equal "is not a PNG, JPEG, or WebP image", assert_body_error("GIF89a....").message
    svg = %(<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>)
    assert_match(/SVG is not accepted/, assert_body_error(svg).message)
  end

  def test_requires_https_on_the_default_port_without_credentials
    assert_equal "must be an https URL", assert_fetch_error(url: "http://cdn.example.com/logo").message
    assert_equal "must be an https URL", assert_fetch_error(url: "file:///etc/passwd").message
    assert_equal "must be an https URL", assert_fetch_error(url: "not a url").message
    assert_equal "must use the default https port", assert_fetch_error(url: "https://cdn.example.com:8443/logo").message
    assert_equal "must not include credentials", assert_fetch_error(url: "https://user:pw@cdn.example.com/logo").message
  end

  def test_blocks_private_loopback_link_local_and_metadata_addresses
    %w[
      127.0.0.1 10.1.2.3 172.16.0.1 192.168.1.1 169.254.169.254 0.0.0.0 100.64.0.1
      ::1 :: fe80::1 fd00:ec2::254 ::ffff:127.0.0.1 ::ffff:169.254.169.254 64:ff9b::a9fe:a9fe not-an-ip
    ].each do |address|
      assert RemoteImage.blocked_address?(address), "#{address} should be blocked"
    end
    refute RemoteImage.blocked_address?("93.184.216.34")
    refute RemoteImage.blocked_address?("2606:2800:220:1:248:1893:25c8:1946")
  end

  def test_never_connects_when_the_host_resolves_to_a_blocked_address
    transport = FakeTransport.new({})

    error = assert_fetch_error(addresses: { "cdn.example.com" => ["93.184.216.34", "169.254.169.254"] },
                               transport: transport)

    assert_equal "host is not a public address", error.message
    assert_empty transport.calls
  end

  def test_unresolvable_host_is_an_error
    error = assert_fetch_error(addresses: { "cdn.example.com" => [] })

    assert_equal "host could not be resolved", error.message
  end

  def test_checks_every_redirect_hop
    transport = FakeTransport.new(
      "https://cdn.example.com/logo" => redirect("https://internal.example.com/latest/meta-data/")
    )

    error = assert_fetch_error(
      addresses: { "cdn.example.com" => ["93.184.216.34"], "internal.example.com" => ["169.254.169.254"] },
      transport: transport
    )

    assert_equal "host is not a public address", error.message
    assert_equal 1, transport.calls.size
  end

  def test_follows_a_relative_redirect_to_a_public_host
    transport = FakeTransport.new(
      "https://cdn.example.com/logo" => redirect("/files/logo.png"),
      "https://cdn.example.com/files/logo.png" => ok(PNG)
    )

    assert_equal "image/png", fetch("https://cdn.example.com/logo", transport: transport).content_type
  end

  def test_redirect_to_http_is_refused
    transport = FakeTransport.new("https://cdn.example.com/logo" => redirect("http://cdn.example.com/logo.png"))

    assert_equal "must be an https URL", assert_fetch_error(transport: transport).message
  end

  def test_limits_redirects
    responses = (0..RemoteImage::MAX_REDIRECTS).to_h do |hop|
      ["https://cdn.example.com/#{hop}", redirect("https://cdn.example.com/#{hop + 1}")]
    end

    error = assert_fetch_error(url: "https://cdn.example.com/0", transport: FakeTransport.new(responses))

    assert_equal "redirected more than #{RemoteImage::MAX_REDIRECTS} times", error.message
  end

  def test_rejects_a_declared_size_over_the_limit_before_reading
    response = ok(PNG, "content-length" => "1048577")
    response.chunks = [] # would be fine, but the header already says too big

    error = assert_fetch_error(transport: FakeTransport.new("https://cdn.example.com/logo" => response),
                               max_bytes: 1024 * 1024)

    assert_equal "is larger than 1 MB", error.message
  end

  def test_stops_reading_once_the_body_passes_the_limit
    chunks = Array.new(3) { "x" * 600_000 }
    response = FakeResponse.new("200", {}, [PNG] + chunks)

    error = assert_fetch_error(transport: FakeTransport.new("https://cdn.example.com/logo" => response),
                               max_bytes: 1024 * 1024)

    assert_equal "is larger than 1 MB", error.message
  end

  def test_non_success_status_is_an_error
    response = FakeResponse.new("404", {}, [])

    transport = FakeTransport.new("https://cdn.example.com/logo" => response)

    assert_equal "returned HTTP 404", assert_fetch_error(transport: transport).message
  end

  def test_network_failures_become_errors
    transport = Object.new
    def transport.get(*, **) = raise(Net::OpenTimeout)

    assert_equal "could not be downloaded", assert_fetch_error(transport: transport).message
  end

  private

  def fetch(url, transport:, addresses: { "cdn.example.com" => ["93.184.216.34"] }, max_bytes: 5 * 1024 * 1024)
    RemoteImage.stub(:resolve, ->(host) { addresses.fetch(host, []) }) do
      RemoteImage.stub(:transport, transport) do
        RemoteImage.fetch(url, max_bytes: max_bytes)
      end
    end
  end

  def fetch_body(body)
    fetch("https://cdn.example.com/logo", transport: FakeTransport.new("https://cdn.example.com/logo" => ok(body)))
  end

  def assert_body_error(body)
    assert_fetch_error(transport: FakeTransport.new("https://cdn.example.com/logo" => ok(body)))
  end

  def assert_fetch_error(url: "https://cdn.example.com/logo", transport: FakeTransport.new({}), **options)
    assert_raises(RemoteImage::Error) { fetch(url, transport: transport, **options) }
  end

  def ok(body, headers = {})
    FakeResponse.new("200", headers, [body.b])
  end

  def redirect(location)
    FakeResponse.new("302", { "location" => location }, [])
  end
end
