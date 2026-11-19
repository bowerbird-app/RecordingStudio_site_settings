# frozen_string_literal: true

# Users v0.32.0 registers users_update with scope_id: false and no required_role.
# API 1.21.2 rejects that combination while the endpoint registers. Users v0.33.0
# passes required_role: :edit. This dummy stays on the v0.32.0 pin and supplies
# that role so boot can finish.
module DummyUsersUpdateRequiredRole
  def register_users_endpoint!(name, http_verb:, path:, handler:, summary:, description:, input_contract: nil,
                               scope_id: nil)
    return unless RecordingStudioApi.respond_to?(:register_endpoint)
    return if already_registered?(name)

    options = {
      api: RecordingStudioUser::Api::USERS_API,
      http_verb: http_verb,
      path: path,
      handler: handler,
      openapi: { tags: ["Users"], summary: summary, description: description },
      input_contract: input_contract
    }
    options[:scope_id] = scope_id unless scope_id.nil?
    options[:required_role] = :edit if name == RecordingStudioUser::Api::USERS_UPDATE_ENDPOINT
    RecordingStudioApi.register_endpoint(name, **options)
  end
end

registration = RecordingStudioUser::Api::Registration
unless registration.singleton_class.ancestors.include?(DummyUsersUpdateRequiredRole)
  registration.singleton_class.prepend(DummyUsersUpdateRequiredRole)
end

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/account"
  config.profile_route_path = "me"
  config.layout = "recording_studio/default_layout"
  # Seeded demo accounts use an 8 character password.
  config.minimum_password_length = 8
end
