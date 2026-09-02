# frozen_string_literal: true

RecordingStudioSiteSettings.configure do |config|
  config.site_root_types = ["Workspace"]
  config.site_root_resolver = lambda do |context|
    controller = context.controller
    recording = controller.try(:current_root_recording)
    return recording if RecordingStudioSiteSettings.site_root?(recording)

    workspace = Workspace.find_by(name: "Studio") || Workspace.order(:created_at).first
    RecordingStudio.root_recording_for(workspace) if workspace
  end
end
