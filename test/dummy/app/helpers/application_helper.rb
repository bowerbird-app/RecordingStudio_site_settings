module ApplicationHelper
  def dummy_sidebar_wide_logo
    return unless respond_to?(:current_root_recording) && current_root_recording.present?

    recording_studio_site_wide_logo(current_root_recording, width: 192)
  end

  def dummy_wide_logo_sidebar(&block)
    render layout: "application/wide_logo_sidebar" do
      capture(&block)
    end
  end

  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          url: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
