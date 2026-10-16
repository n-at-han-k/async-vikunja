# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

module Async
	module Firefly
		class Error < StandardError
		end

		class Failure < Error
			def initialize(message, status:, payload: nil)
				super(message)

				@status = status
				@payload = payload
			end

			attr :status
			attr :payload
		end

		class Duplicate < Failure
		end
	end
end
