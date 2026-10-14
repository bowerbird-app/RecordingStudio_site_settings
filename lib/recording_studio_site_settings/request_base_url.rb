# frozen_string_literal: true

module RecordingStudioSiteSettings
  # Remembers the current request's base URL (scheme, host, port; proxy headers honored, after the host app's
  # host authorization) so API payloads can return absolute preview URLs. Cleared after every request.
  class RequestBaseUrl
    KEY = :recording_studio_site_settings_request_base_url

    class << self
      def current
        Thread.current[KEY]
      end

      def with(base_url)
        previous = Thread.current[KEY]
        Thread.current[KEY] = base_url
        yield
      ensure
        Thread.current[KEY] = previous
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      base_url = begin
        ActionDispatch::Request.new(env).base_url
      rescue StandardError
        nil
      end
      status, headers, body = self.class.with(base_url) { @app.call(env) }
      [status, headers, BodyProxy.new(body, base_url)]
    end

    # Streamed bodies (e.g. MCP Streamable HTTP SSE) run their work inside #each, after #call has returned and the
    # thread-local has been cleared. Re-establish the base URL while the server iterates the body.
    class BodyProxy
      def initialize(body, base_url)
        @body = body
        @base_url = base_url
      end

      def each(&block)
        RequestBaseUrl.with(@base_url) { @body.each(&block) }
      end

      # Only exposed when the wrapped body is itself a streaming (callable) body.
      def call(stream)
        raise NoMethodError, "undefined method `call' for body" unless @body.respond_to?(:call)

        RequestBaseUrl.with(@base_url) { @body.call(stream) }
      end

      def respond_to?(name, include_private = false) # rubocop:disable Style/OptionalBooleanParameter
        return @body.respond_to?(:call) if name.to_sym == :call
        return @body.respond_to?(:each) if name.to_sym == :each

        super
      end

      def close
        @body.close if @body.respond_to?(:close)
      end

      def respond_to_missing?(name, include_private = false)
        return false if name.to_sym == :to_ary

        @body.respond_to?(name, include_private)
      end

      def method_missing(name, *, &)
        return super if name.to_sym == :to_ary

        @body.respond_to?(name) ? @body.public_send(name, *, &) : super
      end
    end
  end
end
