# frozen_string_literal: true

require "ipaddr"

module RecordingStudioSiteSettings
  module Api
    class RemoteImage
      # Addresses a logo download may never reach: private, loopback, link-local (cloud metadata),
      # carrier-grade NAT, reserved, multicast, and IPv6 wrappers that can carry such an address.
      module AddressPolicy
        BLOCKED_RANGES = %w[
          0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24
          203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 ::/128 64:ff9b::/96 64:ff9b:1::/48 100::/64
          2001::/32 2001:db8::/32 2002::/16 ff00::/8
        ].map { |range| IPAddr.new(range) }.freeze

        module_function

        def blocked?(address)
          ip = IPAddr.new(address.to_s.split("%").first).native
          ip.private? || ip.loopback? || ip.link_local? || BLOCKED_RANGES.any? { |range| range.include?(ip) }
        rescue IPAddr::Error
          true
        end
      end
    end
  end
end
