# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require "async/rest/representation"

require_relative "redacted"
require_relative "wrapper"

module Async
	module Firefly
		class Representation < Async::REST::Representation[Wrapper]
			include Redacted

			def deconstruct_keys(keys)
				case self.value
				in Hash => value then value
				else {}
				end
			end

			def deconstruct
				case self.value
				in Array => value then value
				else []
				end
			end

			def cacheable?
				if cache_control = self.metadata["cache-control"]
					!cache_control.no_store?
				else
					true
				end
			end

			def data
				self.value[:data]
			end

			def attributes
				case self.data
				in {attributes: Hash => attributes} then attributes
				else {}
				end
			end
		end
	end
end
