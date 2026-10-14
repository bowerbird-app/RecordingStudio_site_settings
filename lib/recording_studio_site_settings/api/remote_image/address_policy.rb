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

        # allowed: CIDRs (IPAddr) the host app opted in to. They can lift private and reserved ranges,
        # never loopback, link-local, or the unspecified address.
        def blocked?(address, allowed: [])
          ip = IPAddr.new(address.to_s.split("%").first).native
          return true if never_allowed?(ip)
          return false if Array(allowed).any? { |range| range.include?(ip) }

          ip.private? || BLOCKED_RANGES.any? { |range| range.include?(ip) }
        rescue IPAddr::Error
          true
        end

        def never_allowed?(ip)
          ip.loopback? || ip.link_local? || ip.to_i.zero?
        rescue IPAddr::Error
          true
        end
      end
    end
  end
end
