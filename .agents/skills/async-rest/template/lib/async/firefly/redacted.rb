# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

module Async
	module Firefly
		module Redacted
			SECRET = [:access_token, :refresh_token, :client_secret, :password, :token].freeze
			REDACTED = "[redacted]"

			def self.redact(value)
				case value
				when Hash
					value.to_h{|key, nested| SECRET.include?(key) ? [key, REDACTED] : [key, self.redact(nested)]}
				when Array
					value.map{|each| self.redact(each)}
				else
					value
				end
			end

			def inspect
				"\#<#{self.class} #{@resource.path.to_s.inspect} value=#{Redacted.redact(@value).inspect}>"
			end
		end
	end
end
