# frozen_string_literal: true

# Test-only probe that renders the real public logo helpers so host-override
# asserts go through application_helper (blank name → i18n alt fallbacks).
# Not linked from product UI.
class LocaleProbesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_actor
  layout false

  def helper_alts
    @root = RecordingStudio::Recording.find(params.fetch(:root_recording_id))
  end
end
