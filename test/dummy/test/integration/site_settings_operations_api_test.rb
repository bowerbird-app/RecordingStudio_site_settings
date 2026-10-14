# frozen_string_literal: true

require "test_helper"

class SiteSettingsOperationsApiTest < ActionDispatch::IntegrationTest
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"
  RemoteImage = RecordingStudioSiteSettings::Api::RemoteImage
  PUBLIC_ADDRESS = "93.184.216.34"

  FakeResponse = Struct.new(:code, :headers, :body) do
    def [](name)
      headers[name.downcase]
    end

    def read_body
      yield body
    end
  end

  # Stands in for the network: only the URLs given here answer, and every request is recorded.
  class FakeTransport
    attr_reader :calls

    def initialize(responses)
      @responses = responses
      @calls = []
    end

    def get(uri, address:)
      @calls << [ uri.to_s, address ]
      yield @responses.fetch(uri.to_s)
    end
  end

  setup do
    @staff = create_user("api-staff-#{SecureRandom.hex(4)}@example.com")
    Current.actor = @staff
    @site_root = admin_root_recording
    @other_root = empty_admin_root_recording
    grant_site_settings_admin!(@staff)
    bootstrap_owner_access!(@staff, @other_root)
    RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @staff)

    @admin_token = provision_token(name: "Site admin", access_point: @site_root, role: :edit, grant_role: :admin)
    @viewer_token = provision_token(name: "Site viewer", access_point: @site_root, role: :view, grant_role: :view)
    @other_root_token = provision_token(name: "Other root admin", access_point: @other_root, role: :edit,
                                        grant_role: :admin)
  end

  teardown do
    Current.actor = nil
  end

  test "both endpoints are registered on operations with an input contract for update" do
    show = RecordingStudioApi.registered_endpoint(:site_settings_show, api: :operations)
    update = RecordingStudioApi.registered_endpoint(:site_settings_update, api: :operations)

    assert_equal RecordingStudioSiteSettings::Api::Show, show.handler
    assert_equal :get, show.http_verb
    assert_equal "site_settings", show.path
    assert_equal RecordingStudioSiteSettings::Api::Update, update.handler
    assert_equal :patch, update.http_verb
    assert_equal "site_settings", update.path
    assert_equal [ "Site settings" ], update.openapi.fetch(:tags)
    assert_includes update.input_contract.as_json.fetch(:fields).keys, :name
    file_params = update.openapi.fetch(:"x-mcp-file-params")
    assert_equal %i[square_logo_file wide_logo_file favicon_file], file_params.keys.map(&:to_sym)
    assert_nil RecordingStudioApi.registered_endpoint(:site_settings_show, api: :public)
  end

  test "preview_url loads without a session, expires, and rejects tampering" do
    File.open(TEST_SQUARE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @staff, square_logo_io: io,
                                                      square_logo_filename: "square-logo.png",
                                                      square_logo_content_type: "image/png")
    end
    get "#{OPERATIONS_ROOT}/site_settings", headers: auth(@viewer_token), as: :json
    url = response.parsed_body.dig("square_logo", "preview_url")
    path = URI.parse(url).path
    reset!

    get path
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "image/png", response.media_type

    reset!
    tampered = path.sub(%r{redirect/([^/]+)/}) { "redirect/#{Regexp.last_match(1).reverse}/" }
    get tampered
    assert_response :not_found

    travel RecordingStudioSiteSettings.configuration.preview_url_expires_in + 1 do
      get path
      assert_response :not_found
    end
  end

  test "missing token is unauthorized" do
    get "#{OPERATIONS_ROOT}/site_settings", as: :json

    assert_response :unauthorized
  end

  test "a site admin reads the name and each mark" do
    File.open(TEST_SQUARE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @staff, square_logo_io: io,
                                                      square_logo_filename: "square-logo.png",
                                                      square_logo_content_type: "image/png")
    end
    square = RecordingStudioSiteSettings.square_logo_recording_for(@site_root)

    get "#{OPERATIONS_ROOT}/site_settings", headers: auth(@viewer_token), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal %w[favicon name square_logo wide_logo], payload.keys.sort
    assert_equal "Studio", payload.fetch("name")
    refute payload.key?("root_recording_id")
    assert_equal true, payload.dig("square_logo", "present")
    assert_equal square.id, payload.dig("square_logo", "recording_id")
    assert_equal "square-logo.png", payload.dig("square_logo", "filename")
    assert_match %r{\Ahttp://www\.example\.com/rails/active_storage/representations/redirect/[^/]+/[^/]+/square-logo\.png\z},
                 payload.dig("square_logo", "preview_url")
    assert_equal "square_med", payload.dig("square_logo", "variant")
    assert_equal "square_small", payload.dig("favicon", "variant")
    wide = RecordingStudioSiteSettings.wide_logo_for(@site_root, variant: :small)
    assert_equal(
      {
        "present" => wide.present?, "variant" => "small", "recording_id" => wide.recording&.id,
        "filename" => wide.filename
      },
      payload.fetch("wide_logo").except("preview_url")
    )
    favicon = RecordingStudioSiteSettings.favicon_for(@site_root, variant: :square_small)
    assert_equal(
      { "present" => favicon.present?, "recording_id" => favicon.recording&.id },
      payload.fetch("favicon").slice("present", "recording_id")
    )
  end

  test "a site admin renames the site with a stripped name" do
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: { name: "  Renamed  " }, as: :json

    assert_response :success
    assert_equal "Renamed", response.parsed_body.fetch("name")
    assert_equal "Renamed", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "a blank name is a 422 validation failure" do
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: { name: "   " }, as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "an update with neither name nor a mark is a 422" do
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: {}, as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_input", response.parsed_body.dig("error", "code")
    assert_equal [ "Send name, at least one of square_logo_file, wide_logo_file, favicon_file, or both" ],
                 response.parsed_body.dig("error", "details")
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "unknown fields are rejected" do
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: { name: "X", color: "red" },
                                              as: :json

    assert_response :unprocessable_entity
    assert_equal [ "Unknown parameters: color" ], response.parsed_body.dig("error", "details")
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "a site admin sets the square logo from an https URL without changing the name" do
    transport = FakeTransport.new("https://cdn.example.com/square.png" => image_response(TEST_SQUARE_LOGO_PATH))

    with_network(transport) do
      patch_marks({ square_logo_file: "https://cdn.example.com/square.png" })
    end

    assert_response :success
    assert_equal [ [ "https://cdn.example.com/square.png", PUBLIC_ADDRESS ] ], transport.calls
    payload = response.parsed_body
    assert_equal "Studio", payload.fetch("name")
    assert_equal true, payload.dig("square_logo", "present")
    assert_equal "square_logo.png", payload.dig("square_logo", "filename")
    logo = RecordingStudioSiteSettings.square_logo_recording_for(@site_root)
    assert_equal logo.id, payload.dig("square_logo", "recording_id")
    assert_equal "image/png", logo.recordable.content_type
    assert_includes payload.dig("square_logo", "preview_url"), "/rails/active_storage/representations/redirect/"
  end

  test "a ChatGPT file object sets the favicon and a second call replaces it" do
    file = { download_url: "https://files.example.com/download/abc", file_id: "file_abc", mime_type: "image/png",
             file_name: "icon.png" }
    transport = FakeTransport.new(file[:download_url] => image_response(TEST_SQUARE_LOGO_PATH))

    with_network(transport) { patch_marks({ favicon_file: file }) }
    assert_response :success
    first = RecordingStudioSiteSettings.favicon_recording_for(@site_root)

    with_network(transport) { patch_marks({ favicon_file: file }) }
    assert_response :success

    assert_equal first.id, RecordingStudioSiteSettings.favicon_recording_for(@site_root).id
    assert_equal true, response.parsed_body.dig("favicon", "present")
    assert_equal 2, transport.calls.size
  end

  test "name and a mark update together" do
    transport = FakeTransport.new("https://cdn.example.com/wide.png" => image_response(TEST_WIDE_LOGO_PATH))

    with_network(transport) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token),
                                                params: { name: "Both", wide_logo_file: "https://cdn.example.com/wide.png" },
                                                as: :json
    end

    assert_response :success
    assert_equal "Both", response.parsed_body.fetch("name")
    assert_equal true, response.parsed_body.dig("wide_logo", "present")
  end

  test "null clears a mark" do
    File.open(TEST_SQUARE_LOGO_PATH, "rb") do |io|
      RecordingStudioSiteSettings.update!(@site_root, name: "Studio", actor: @staff, favicon_io: io,
                                                      favicon_filename: "favicon.png", favicon_content_type: "image/png")
    end
    assert RecordingStudioSiteSettings.favicon_for(@site_root).present?
    transport = FakeTransport.new({})

    with_network(transport) { patch_marks({ favicon_file: nil }) }

    assert_response :success
    assert_equal false, response.parsed_body.dig("favicon", "present")
    assert_nil RecordingStudioSiteSettings.favicon_recording_for(@site_root)
    assert_empty transport.calls
  end

  test "clearing an empty mark is a no-op" do
    with_network(FakeTransport.new({})) { patch_marks({ wide_logo_file: nil }) }

    assert_response :success
    assert_equal false, response.parsed_body.dig("wide_logo", "present")
  end

  test "a URL that resolves to a private or metadata address is refused before connecting" do
    square_logo_before = square_logo_recordable_id
    transport = FakeTransport.new({})

    with_network(transport, addresses: { "metadata.example.com" => [ "169.254.169.254" ] }) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token),
                                                params: { name: "Nope", square_logo_file: "https://metadata.example.com/latest" },
                                                as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "invalid_input", response.parsed_body.dig("error", "code")
    assert_equal [ "square_logo_file host resolves to a non-public address (169.254.169.254)" ], response.parsed_body.dig("error", "details")
    assert_empty transport.calls
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
    assert_equal square_logo_before, square_logo_recordable_id
  end

  test "the 422 message names the failing check for each mark" do
    with_network(FakeTransport.new({}), addresses: { "files.example.com" => [ "198.18.0.1" ] }) do
      patch_marks({ square_logo_file: { download_url: "https://files.example.com/raw?sig=secret", file_id: "file_1" } })
    end

    assert_response :unprocessable_entity
    assert_equal "Logo could not be used: square_logo_file host resolves to a non-public address (198.18.0.1)",
                 response.parsed_body.dig("error", "message")
    refute_includes response.body, "sig=secret"
  end

  test "a redirect to a loopback address is refused" do
    transport = FakeTransport.new(
      "https://cdn.example.com/logo" => FakeResponse.new("302", { "location" => "https://localhost.example.com/" }, "")
    )

    with_network(transport, addresses: { "localhost.example.com" => [ "127.0.0.1" ] }) do
      patch_marks({ square_logo_file: "https://cdn.example.com/logo" })
    end

    assert_response :unprocessable_entity
    assert_equal [ "square_logo_file host resolves to a non-public address (127.0.0.1)" ], response.parsed_body.dig("error", "details")
    assert_equal 1, transport.calls.size
  end

  test "a plain http URL is refused" do
    with_network(FakeTransport.new({})) { patch_marks({ square_logo_file: "http://cdn.example.com/logo.png" }) }

    assert_response :unprocessable_entity
    assert_equal [ "square_logo_file must be an https URL" ], response.parsed_body.dig("error", "details")
  end

  test "a file that is not a PNG, JPEG, or WebP is refused whatever its header says" do
    square_logo_before = square_logo_recordable_id
    transport = FakeTransport.new(
      "https://cdn.example.com/logo" => FakeResponse.new("200", { "content-type" => "image/png" }, "GIF89a...")
    )

    with_network(transport) { patch_marks({ square_logo_file: "https://cdn.example.com/logo" }) }

    assert_response :unprocessable_entity
    assert_equal [ "square_logo_file is not a PNG, JPEG, or WebP image" ], response.parsed_body.dig("error", "details")
    assert_equal square_logo_before, square_logo_recordable_id
  end

  test "an SVG is refused" do
    svg = %(<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>)
    transport = FakeTransport.new("https://cdn.example.com/logo.svg" => FakeResponse.new("200", {}, svg))

    with_network(transport) { patch_marks({ wide_logo_file: "https://cdn.example.com/logo.svg" }) }

    assert_response :unprocessable_entity
    assert_match(/SVG is not accepted/, response.parsed_body.dig("error", "details").first)
  end

  test "a file over the Site screen's size limit is refused" do
    limit = RecordingStudioAttachable.configuration.max_file_size
    transport = FakeTransport.new(
      "https://cdn.example.com/huge.png" => FakeResponse.new("200", { "content-length" => (limit + 1).to_s }, "")
    )

    with_network(transport) { patch_marks({ square_logo_file: "https://cdn.example.com/huge.png" }) }

    assert_response :unprocessable_entity
    assert_equal [ "square_logo_file is larger than #{limit / 1.megabyte} MB" ],
                 response.parsed_body.dig("error", "details")
  end

  test "one bad logo saves nothing" do
    square_logo_before = square_logo_recordable_id
    transport = FakeTransport.new(
      "https://cdn.example.com/good.png" => image_response(TEST_SQUARE_LOGO_PATH),
      "https://cdn.example.com/bad" => FakeResponse.new("404", {}, "")
    )

    with_network(transport) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token),
                                                params: { name: "Nope", square_logo_file: "https://cdn.example.com/good.png",
                                                          favicon_file: "https://cdn.example.com/bad" },
                                                as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "favicon_file returned HTTP 404" ], response.parsed_body.dig("error", "details")
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
    assert_equal square_logo_before, square_logo_recordable_id
  end

  test "the old nested logos object, unknown fields, and bad values are 422" do
    with_network(FakeTransport.new({})) { patch_marks({ logos: { square_logo: "https://cdn.example.com/a.png" }, favicon_file: 7 }) }

    assert_response :unprocessable_entity
    details = response.parsed_body.dig("error", "details")
    assert_equal 2, details.size
    assert_equal "Unknown parameters: logos", details.first
    assert_match(/favicon_file must be a file object/, details.last)
  end

  test "a viewer cannot set or clear logos and nothing is downloaded" do
    transport = FakeTransport.new({})

    with_network(transport) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@viewer_token),
                                                params: { square_logo_file: "https://cdn.example.com/a.png", favicon_file: nil },
                                                as: :json
    end

    assert_response :forbidden
    assert_empty transport.calls
  end

  test "an admin of another root cannot set logos" do
    transport = FakeTransport.new({})

    with_network(transport) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@other_root_token),
                                                params: { square_logo_file: "https://cdn.example.com/a.png" }, as: :json
    end

    assert_response :forbidden
    assert_empty transport.calls
  end

  test "a site admin without edit on the site root cannot set logos and nothing is downloaded" do
    transport = FakeTransport.new({})

    with_site_root(@other_root) do
      with_network(transport) { patch_marks({ square_logo_file: "https://cdn.example.com/a.png" }) }
    end

    assert_response :forbidden
    assert_empty transport.calls
  end

  test "a viewer can read but cannot rename" do
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@viewer_token), params: { name: "Nope" }, as: :json

    assert_response :forbidden
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "an admin of another root fails the site blast radius gate" do
    get "#{OPERATIONS_ROOT}/site_settings", headers: auth(@other_root_token), as: :json
    assert_response :forbidden

    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@other_root_token), params: { name: "Nope" }, as: :json
    assert_response :forbidden
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
  end

  test "a site admin without edit on a different site root fails authorize_write!" do
    before = RecordingStudioSiteSettings.name_for(@other_root)
    with_site_root(@other_root) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: { name: "Elsewhere" },
                                                as: :json
    end

    assert_response :forbidden
    assert_equal [ before ], [ RecordingStudioSiteSettings.name_for(@other_root) ]
    refute_equal "Elsewhere", RecordingStudioSiteSettings.name_for(@other_root)
  end

  private

  def square_logo_recordable_id
    RecordingStudioSiteSettings.square_logo_recording_for(@site_root)&.recordable_id
  end

  def patch_marks(params)
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: params, as: :json
  end

  # Minitest 6 dropped minitest/mock, so swap RemoteImage's two network seams by hand and put them back.
  def with_network(transport, addresses: {})
    originals = { resolve: RemoteImage.method(:resolve), transport: RemoteImage.method(:transport) }
    RemoteImage.define_singleton_method(:resolve) { |host| addresses.fetch(host) { [ PUBLIC_ADDRESS ] } }
    RemoteImage.define_singleton_method(:transport) { transport }
    yield
  ensure
    originals.each { |name, method| RemoteImage.singleton_class.send(:define_method, name, method) }
  end

  def image_response(path)
    FakeResponse.new("200", {}, File.binread(path))
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(name:, access_point:, role:, grant_role:)
    with_open_access_management do
      result = RecordingStudioApi::Services::ProvisionApiClient.call(
        access_point_recording: access_point, manager_actor: @staff, role: role,
        name: "#{name} #{SecureRandom.hex(4)}", api: :operations
      )
      raise result.error unless result.success?

      payload = result.value
      grant!(access_point, payload.fetch(:api_client), grant_role)
      issue_token(payload)
    end
  end

  def issue_token(payload)
    result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token),
      api: :operations
    )
    raise result.error unless result.success?

    result.value.fetch(:access_token)
  end

  def grant!(recording, actor, role)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role) &&
              role.to_sym != :view

    result = RecordingStudioAccessible.grant_access(recording: recording, actor: actor, role: role,
                                                    manager_actor: @staff)
    raise result.error if result.failure?
  end

  def with_open_access_management
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    yield
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
