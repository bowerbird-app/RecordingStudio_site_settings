# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"

# minitest 6 (pulled by the 6.1 lock) no longer ships minitest/mock Object#stub.
class Object
  def stub(method_name, return_value)
    singleton = singleton_class
    previous = begin
      singleton.instance_method(method_name)
    rescue NameError
      nil
    end

    singleton.define_method(method_name) do |*args, **kwargs, &block|
      if return_value.respond_to?(:call)
        return_value.call(*args, **kwargs, &block)
      else
        return_value
      end
    end

    yield
  ensure
    singleton.remove_method(method_name)
    singleton.define_method(method_name, previous) if previous
  end
end

require "rails"
require "active_record"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_site_settings"
