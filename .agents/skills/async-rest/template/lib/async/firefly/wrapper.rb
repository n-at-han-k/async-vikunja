# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require "async/rest/wrapper/json"

module Async
	module Firefly
		class Wrapper < Async::REST::Wrapper::JSON
			VND_API_JSON = "application/vnd.api+json"

			def response_for(resource, request)
				resource.call(request)
			end

			def parser_for(response)
				if content_type = response.headers["content-type"]
					if content_type.include?("json")
						return Async::REST::Wrapper::JSON::Parser
					end
				end

				super
			end
		end
	end
end
