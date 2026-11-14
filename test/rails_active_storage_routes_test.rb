# frozen_string_literal: true

require "test_helper"

class RailsActiveStorageRoutesTest < Minitest::Test
  SURFACES = %w[app/views app/helpers app/controllers app/javascript app/assets].freeze
  FORBIDDEN = %r{
    rails_direct_uploads_path |
    rails_blob_path |
    rails_blob_url |
    rails_representation_ |
    /rails/active_storage
  }x

  def test_gem_screens_do_not_reference_rails_active_storage_routes
    assert_empty offending_lines
  end

  private

  def offending_lines
    root = File.expand_path("..", __dir__)

    SURFACES.flat_map { |surface| offending_lines_under(root, surface) }
  end

  def offending_lines_under(root, surface)
    directory = File.join(root, surface)
    return [] unless File.directory?(directory)

    Dir.glob(File.join(directory, "**", "*")).flat_map do |path|
      offending_lines_in(root, path)
    end
  end

  def offending_lines_in(root, path)
    return [] unless File.file?(path)
    return [] unless path.match?(/\.(erb|rb|js|css)\z/)

    File.readlines(path).each_with_index.filter_map do |line, index|
      next unless line.match?(FORBIDDEN)

      "#{path.delete_prefix("#{root}/")}:#{index + 1}"
    end
  end
end
