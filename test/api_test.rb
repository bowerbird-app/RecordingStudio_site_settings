# frozen_string_literal: true

require "test_helper"

class ApiTest < Minitest::Test
  FakeEndpoint = Struct.new(:name, :api, :http_verb, :path, :handler, :openapi, :input_contract, keyword_init: true)
  FakeConfiguration = Struct.new(:api_names)

  def teardown
    remove_fake_api!
  end

  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)
    assert_nil RecordingStudioSiteSettings::Api.register!
  end

  def test_gemspec_omits_recording_studio_api_runtime_dependency
    gemspec = File.read(File.expand_path("../recording_studio_site_settings.gemspec", __dir__))

    refute_includes gemspec, '"recording_studio_api"'
  end

  def test_engine_registers_api_in_to_prepare
    engine = File.read(File.expand_path("../lib/recording_studio_site_settings/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_site_settings.api"'
    assert_includes engine, "config.to_prepare { RecordingStudioSiteSettings::Api.register! }"
  end

  def test_registers_show_and_update_on_operations
    api = install_fake_api!

    assert RecordingStudioSiteSettings::Api.register!

    assert_equal %i[site_settings_show site_settings_update], api.endpoints.map(&:name)
    show, update = api.endpoints
    assert(api.endpoints.all? { |endpoint| endpoint.api == :operations && endpoint.path == "site_settings" })
    assert_equal :get, show.http_verb
    assert_equal RecordingStudioSiteSettings::Api::Show, show.handler
    assert_nil show.input_contract
    assert_equal :patch, update.http_verb
    assert_equal RecordingStudioSiteSettings::Api::Update, update.handler
    assert_equal ["Site settings"], update.openapi.fetch(:tags)
    assert update.openapi.fetch(:summary).present?
    assert update.openapi.fetch(:description).present?
    assert_equal({ type: :string, required: false }, update.input_contract.dig(:fields, :name).slice(:type, :required))
    assert_equal({ type: :hash, required: false }, update.input_contract.dig(:fields, :logos).slice(:type, :required))
    assert_includes update.input_contract.dig(:fields, :logos, :description), "square_logo, wide_logo, favicon"
  end

  def test_update_input_reads_urls_file_objects_and_clears
    install_fake_api!
    input = RecordingStudioSiteSettings::Api::UpdateInput.parse!(
      logos: {
        square_logo: " https://cdn.example.com/square.png ",
        "wide_logo" => { download_url: "https://files.example.com/x", file_id: "file_123", mime_type: "image/png",
                         file_name: "wide.png" },
        favicon: nil
      }
    )

    refute input.name_given?
    expected = { "square_logo" => "https://cdn.example.com/square.png", "wide_logo" => "https://files.example.com/x" }
    assert_equal expected, input.sources
    assert_equal ["favicon"], input.clears
  end

  def test_update_input_strips_a_given_name
    install_fake_api!
    input = RecordingStudioSiteSettings::Api::UpdateInput.parse!(name: "  Studio  ")

    assert input.name_given?
    assert_equal "Studio", input.name
  end

  def test_update_input_needs_name_or_logos
    install_fake_api!

    [{}, { logos: {} }, nil].each do |params|
      error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
        RecordingStudioSiteSettings::Api::UpdateInput.parse!(params)
      end
      assert_equal ["Send name, logos, or both"], error.details
    end
  end

  def test_update_input_rejects_unknown_marks_and_bad_values
    install_fake_api!

    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioSiteSettings::Api::UpdateInput.parse!(
        logos: {
          banner: "https://cdn.example.com/a.png",
          square_logo: 42,
          wide_logo: { download_url: "https://files.example.com/x" },
          favicon: { download_url: "https://files.example.com/x", file_id: "file_1", extra: true }
        }
      )
    end

    assert_equal 4, error.details.size
    assert_match(/logos\.banner is not a mark/, error.details.first)
    assert(error.details.drop(1).all? { |detail| detail.include?("must be an https URL, a file object") })
  end

  def test_update_input_rejects_a_non_object_logos_value
    install_fake_api!

    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioSiteSettings::Api::UpdateInput.parse!(logos: "https://cdn.example.com/a.png")
    end

    assert_match(/logos must be an object/, error.details.first)
  end

  def test_registration_skips_already_registered_endpoints
    api = install_fake_api!

    2.times { RecordingStudioSiteSettings::Api.register! }

    assert_equal %i[site_settings_show site_settings_update], api.endpoints.map(&:name)
  end

  def test_registration_requires_the_operations_api
    api = install_fake_api!(api_names: %w[public])

    RecordingStudioSiteSettings::Api.register!

    assert_empty api.endpoints
  end

  def test_mark_variants_cover_every_image_slot
    assert_equal RecordingStudioSiteSettings::Store::IMAGE_SLOTS.keys.sort,
                 RecordingStudioSiteSettings::Admin::MARK_VARIANTS.keys.sort
  end

  def test_update_maps_store_denial_to_api_authorization_error
    install_fake_api!
    update = RecordingStudioSiteSettings::Api::Update.new(nil)
    root = Object.new
    access = RecordingStudioSiteSettings::Api::Access

    access.stub(:write, root) do
      deny = ->(*) { raise RecordingStudioSiteSettings::Unauthorized, "no" }
      RecordingStudioSiteSettings::Store.stub(:authorize_write!, deny) do
        assert_raises(RecordingStudioApi::AuthorizationError) { update.call }
      end
    end
  end

  private

  def install_fake_api!(api_names: %w[public operations])
    api = Module.new
    api.const_set(:AuthorizationError, Class.new(StandardError))
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, Class.new(StandardError) do
      attr_reader :details

      def initialize(message = nil, details: [])
        super(message)
        @details = details
      end
    end)
    endpoints = []
    configuration = FakeConfiguration.new(api_names)
    api.define_singleton_method(:endpoints) { endpoints }
    api.define_singleton_method(:configuration) { configuration }
    api.define_singleton_method(:register_endpoint) do |name, **options|
      endpoints << FakeEndpoint.new(name: name, **options.slice(*FakeEndpoint.members))
    end
    api.define_singleton_method(:registered_endpoint) do |name, api: :public|
      endpoints.find { |endpoint| endpoint.name == name && endpoint.api == api }
    end
    Object.const_set(:RecordingStudioApi, api)
  end

  def remove_fake_api!
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end
end
