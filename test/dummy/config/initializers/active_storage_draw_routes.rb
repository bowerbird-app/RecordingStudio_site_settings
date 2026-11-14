# frozen_string_literal: true

# Active Storage copies config.active_storage.draw_routes onto
# ActiveStorage.draw_routes in after_initialize, which runs after eager route
# loading. Set the flag here so the engine route file sees it when CI eager-loads.
ActiveStorage.draw_routes = Rails.application.config.active_storage.draw_routes
