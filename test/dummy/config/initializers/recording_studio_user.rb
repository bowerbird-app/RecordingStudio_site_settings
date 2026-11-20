# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/account"
  config.profile_route_path = "me"
  config.layout = "recording_studio/default_layout"
  # Seeded demo accounts use an 8 character password.
  config.minimum_password_length = 8
end
