# frozen_string_literal: true

require "net/http"
require "openssl"
require "socket"
require "stringio"
require_relative "remote_image/address_policy"
require_relative "remote_image/sniff"
require_relative "remote_image/transport"

module RecordingStudioSiteSettings
  module Api
    # Downloads one logo image for the API. HTTPS on port 443 only, a few redirects at most, and
    # every hop is resolved and checked so private, loopback, link-local, and metadata addresses
    # are never contacted. The connection is pinned to the checked address. The type comes from
    # the file's first bytes, not from headers or the URL.
    class RemoteImage
      class Error < StandardError; end

      Download = Data.define(:io, :content_type, :extension)

      MAX_REDIRECTS = 3
      TOTAL_TIMEOUT = 15
      DEFAULT_MAX_BYTES = 5 * 1024 * 1024
      REDIRECT_CODES = %w[301 302 303 307 308].freeze

      class << self
        def fetch(url, max_bytes: DEFAULT_MAX_BYTES)
          new(max_bytes: max_bytes).fetch(url)
        end

        def resolve(host)
          Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq
        rescue SocketError
          []
        end

        def transport
          Transport
        end

        def blocked_address?(address)
          AddressPolicy.blocked?(address,
                                 allowed: RecordingStudioSiteSettings.configuration.remote_image_allowed_networks)
        end
      end

      def initialize(max_bytes:)
        @max_bytes = max_bytes
        @deadline = monotonic_now + TOTAL_TIMEOUT
      end

      def fetch(url)
        uri = parse!(url)
        (MAX_REDIRECTS + 1).times do
          result = get(uri)
          return result if result.is_a?(Download)

          uri = parse!(result)
        end
        raise Error, "redirected more than #{MAX_REDIRECTS} times"
      end

      private

      attr_reader :max_bytes, :deadline

      def parse!(value)
        uri = URI.parse(value.to_s.strip)
        raise Error, "must be an https URL" unless uri.is_a?(URI::HTTPS) && uri.hostname.present?
        raise Error, "must not include credentials" if uri.userinfo.present?
        raise Error, "must use the default https port" unless uri.port == URI::HTTPS::DEFAULT_PORT

        uri
      rescue URI::InvalidURIError
        raise Error, "must be an https URL"
      end

      def get(uri)
        address = public_address!(uri.hostname)
        self.class.transport.get(uri, address: address) { |response| handle(response, uri) }
      rescue Error
        raise
      rescue *Transport::FAILURES.keys.flatten => e
        raise Error, "could not be downloaded: #{Transport.failure_reason(e)}"
      end

      def public_address!(host)
        addresses = self.class.resolve(host)
        raise Error, "host could not be resolved" if addresses.empty?

        blocked = addresses.find { |address| self.class.blocked_address?(address) }
        raise Error, "host resolves to a non-public address (#{blocked})" if blocked

        addresses.first
      end

      def handle(response, uri)
        code = response.code.to_s
        return redirect_target(response, uri) if REDIRECT_CODES.include?(code)
        raise Error, "returned HTTP #{code}" unless code == "200"

        declared = response["content-length"]
        raise Error, too_big_message if declared.present? && declared.to_i > max_bytes

        sniff!(read_limited(response))
      end

      def redirect_target(response, uri)
        location = response["location"].to_s
        raise Error, "redirected without a location" if location.blank?

        URI.join(uri.to_s, location).to_s
      rescue URI::Error
        raise Error, "redirected to an invalid URL"
      end

      def read_limited(response)
        body = +"".b
        response.read_body do |chunk|
          body << chunk.b
          raise Error, too_big_message if body.bytesize > max_bytes
          raise Error, "took too long to download" if monotonic_now > deadline
        end
        body
      end

      def sniff!(bytes)
        type = Sniff.type_for(bytes)
        raise Error, "SVG is not accepted; send a PNG, JPEG, or WebP image" if type.nil? && Sniff.svg?(bytes)
        raise Error, "is not a PNG, JPEG, or WebP image" if type.nil?

        Download.new(io: StringIO.new(bytes), content_type: type.first, extension: type.last)
      end

      def too_big_message
        "is larger than #{max_bytes / 1024 / 1024} MB"
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
