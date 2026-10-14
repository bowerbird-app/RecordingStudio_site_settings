# frozen_string_literal: true

require "test_helper"

class SiteSettingsOperationsApiTest < ActionDispatch::IntegrationTest
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"

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
    assert_nil RecordingStudioApi.registered_endpoint(:site_settings_show, api: :public)
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
    assert_includes payload.dig("square_logo", "preview_url"), square.id
    assert_equal(
      { "present" => false, "recording_id" => nil, "filename" => nil, "preview_url" => nil },
      payload.fetch("wide_logo")
    )
    assert_equal false, payload.dig("favicon", "present")
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

  test "a missing name is rejected by the input contract" do
    patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: {}, as: :json

    assert_response :unprocessable_entity
    assert_equal "Studio", RecordingStudioSiteSettings.name_for(@site_root)
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
    with_site_root(@other_root) do
      patch "#{OPERATIONS_ROOT}/site_settings", headers: auth(@admin_token), params: { name: "Elsewhere" },
                                                as: :json
    end

    assert_response :forbidden
    assert_nil RecordingStudioSiteSettings.name_for(@other_root)
  end

  private

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
