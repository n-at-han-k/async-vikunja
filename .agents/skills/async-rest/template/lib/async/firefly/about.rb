# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require_relative "representation"

module Async
	module Firefly
		class About < Representation
			def version
				self.data[:version]
			end

			def api_version
				self.data[:api_version]
			end

			def os
				self.data[:os]
			end
		end
	end
end
