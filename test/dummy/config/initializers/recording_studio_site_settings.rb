# frozen_string_literal: true

RecordingStudioSiteSettings.configure do |config|
  config.site_root_types = ["AdminRoot"]
  config.site_root_resolver = lambda do |context|
    controller = context.respond_to?(:controller) ? context.controller : context
    recording = controller.try(:current_root_recording)
    return recording if RecordingStudioSiteSettings.site_root?(recording)

    admin_root = AdminRoot.find_by(name: "Admin") || AdminRoot.order(:created_at).first
    RecordingStudio.root_recording_for(admin_root) if admin_root
  end
end
