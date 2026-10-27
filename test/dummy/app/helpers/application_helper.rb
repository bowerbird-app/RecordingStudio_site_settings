module ApplicationHelper
  def dummy_site_root_recording
    RecordingStudioSiteSettings.site_root_for(controller)
  end

  def dummy_sidebar_wide_logo
    site_root = dummy_site_root_recording
    return if site_root.blank?

    recording_studio_site_wide_logo(site_root, width: 192)
  end

  def dummy_wide_logo_sidebar(&block)
    render layout: "application/wide_logo_sidebar" do
      capture(&block)
    end
  end

  def dummy_page_nav(back_url: nil, back_label: "Home")
    if back_url.present?
      flat_pack_page_nav(
        round: true,
        style: :default,
        back_href: back_url,
        back_tooltip: back_label
      )
    end

    switch = recording_studio_root_switch_for(style: :ghost, size: :md)
    register_page_nav(component: switch, role: :secondary) if switch

    register_page_nav(
      "Sign out",
      main_app.destroy_user_session_path,
      role: :secondary,
      data: { turbo_method: :delete }
    )
  end
end
