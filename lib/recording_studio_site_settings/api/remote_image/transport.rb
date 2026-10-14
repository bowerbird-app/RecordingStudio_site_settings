# frozen_string_literal: true

require "net/http"
require "openssl"

module RecordingStudioSiteSettings
  module Api
    class RemoteImage
      # Net::HTTP pinned to an already-checked address. No proxy, no retries, short timeouts.
      module Transport
        OPEN_TIMEOUT = 3
        READ_TIMEOUT = 5
        ACCEPT = "image/png, image/jpeg, image/webp"
        # Which step failed, without hostnames, addresses, or library messages.
        FAILURES = {
          [Timeout::Error] => "the host timed out",
          [OpenSSL::SSL::SSLError] => "the TLS handshake or certificate check failed",
          [SocketError, SystemCallError] => "the connection failed",
          [IOError, Net::HTTPBadResponse] => "the response was invalid"
        }.freeze

        module_function

        def get(uri, address:)
          build(uri, address).start do |connection|
            connection.request(Net::HTTP::Get.new(uri, "Accept" => ACCEPT)) { |response| return yield(response) }
          end
        end

        def failure_reason(error)
          FAILURES.find { |classes, _reason| classes.any? { |klass| error.is_a?(klass) } }&.last
        end

        def build(uri, address)
          Net::HTTP.new(uri.hostname, uri.port, nil).tap do |http|
            http.ipaddr = address
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            http.open_timeout = http.ssl_timeout = OPEN_TIMEOUT
            http.read_timeout = http.write_timeout = READ_TIMEOUT
            http.max_retries = 0
          end
        end
      end
    end
  end
end
