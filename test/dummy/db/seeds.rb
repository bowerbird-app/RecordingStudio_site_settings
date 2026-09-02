find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

bootstrap_owner_access = lambda do |actor, recording|
  result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
  raise result.error if result.failure?
end

seed_user = lambda do |email:, first_name:, last_name:|
  user = User.find_or_initialize_by(email: email)
  user.password = user.password_confirmation = "Password" if user.new_record?
  user.save! if user.new_record? || user.changed?

  if RecordingStudioUser.profile_for(user).nil?
    RecordingStudioUser.record_profile!(
      user,
      first_name: first_name,
      last_name: last_name,
      time_zone: "UTC",
      actor: user
    )
  end

  user
end

previous_actor = Current.actor

begin
  user = seed_user.call(email: "admin@admin.com", first_name: "Avery", last_name: "Admin")
  member = seed_user.call(email: "member@admin.com", first_name: "Morgan", last_name: "Member")
  Current.actor = user

  workspace = Workspace.find_or_create_by!(name: "Studio")
  empty_logo_workspace = Workspace.find_or_create_by!(name: "Client Studio")
  folder = Folder.find_or_create_by!(name: "Product Docs")
  page = Page.find_or_create_by!(title: "Getting Started")

  root_recording = RecordingStudio.root_recording_for(workspace)
  empty_logo_root = RecordingStudio.root_recording_for(empty_logo_workspace)
  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)

  admin_root = AdminRoot.find_or_create_by!(name: "Admin")
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)

  bootstrap_owner_access.call(user, admin_root_recording)
  bootstrap_owner_access.call(user, root_recording)
  bootstrap_owner_access.call(user, empty_logo_root)

  RecordingStudioSiteSettings.update!(
    root_recording,
    name: "Studio",
    actor: user
  )
  unless RecordingStudioSiteSettings.square_logo_for(root_recording).present?
    File.open(Rails.root.join("db/seeds/square-logo.png"), "rb") do |io|
      RecordingStudioSiteSettings.update!(
        root_recording,
        name: "Studio",
        actor: user,
        square_logo_io: io,
        square_logo_filename: "square-logo.png",
        square_logo_content_type: "image/png"
      )
    end
  end
  unless RecordingStudioSiteSettings.wide_logo_for(root_recording).present?
    File.open(Rails.root.join("db/seeds/wide-logo.png"), "rb") do |io|
      RecordingStudioSiteSettings.update!(
        root_recording,
        name: "Studio",
        actor: user,
        wide_logo_io: io,
        wide_logo_filename: "wide-logo.png",
        wide_logo_content_type: "image/png"
      )
    end
  end

  RecordingStudioSiteSettings.update!(
    empty_logo_root,
    name: "Client Studio",
    actor: user
  )
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: member@admin.com / Password (no admin access)"
puts "Seeded: Studio with name, square logo, and wide logo"
puts "Seeded: Client Studio with name and empty marks"
puts "Seeded: no favicon on either site"
puts "Seeded: Admin root for the site settings screen"
