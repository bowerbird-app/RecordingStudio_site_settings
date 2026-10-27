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

  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    content_for(:title, title)
    content_for(:subtitle, subtitle) if subtitle.present?

    if back_url.present?
      flat_pack_page_nav(
        round: true,
        style: :default,
        back_href: back_url,
        back_tooltip: back_label
      )
    end

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
    end

    register_page_nav(
      role: :secondary,
      component: FlatPack::Button::Component.new(
        text: "Sign out",
        style: :ghost,
        size: :sm,
        href: main_app.destroy_user_session_path,
        data: { turbo_method: :delete }
      )
    )
  end
end
