# frozen_string_literal: true

# Test-only probes for boot-order / fresh-backend host locale overrides.
# Not linked from product UI.
class LocaleProbesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_actor

  def boot_override
    render plain: I18n.t("recording_studio.site_settings.probes.boot_override")
  end

  def helper_alts
    render plain: [
      RecordingStudioSiteSettings::Copy.t("helpers.square_logo_alt"),
      RecordingStudioSiteSettings::Copy.t("helpers.wide_logo_alt")
    ].join("\n")
  end
end
