# frozen_string_literal: true

# Test-only probe that renders real helper alt keys for host-override asserts.
# Not linked from product UI.
class LocaleProbesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_actor

  def helper_alts
    render plain: [
      RecordingStudioSiteSettings::Copy.t("helpers.square_logo_alt"),
      RecordingStudioSiteSettings::Copy.t("helpers.wide_logo_alt")
    ].join("\n")
  end
end
