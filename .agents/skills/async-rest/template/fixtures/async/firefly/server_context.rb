# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require "sus/fixtures/async/http/server_context"

require "async/firefly/client"

module Async
	module Firefly
		# Serves canned Firefly responses and records every request, because rule 11 establishes
		# conformance from what went on the wire rather than from the client's structure.
		#
		# `client`, `app` and `middleware` are all defined by ServerContext, so the client under
		# test is `firefly` and the routes are installed through `middleware`.
		ServerContext = Sus::Shared("a firefly server") do
			include Sus::Fixtures::Async::HTTP::ServerContext

			let(:requests) {[]}

			let(:responses) {{}}

			let(:middleware) do
				recorded = requests
				canned = responses

				::Protocol::HTTP::Middleware.for do |request|
					path, query = request.path.split("?", 2)

					recorded << {
						method: request.method,
						path: path,
						query: query && ::Protocol::URL::Encoding.decode(query, symbolize_keys: true),
						headers: request.headers.to_h,
						payload: request.body&.join,
					}

					status, body = canned.fetch([request.method, path]) do
						[404, {message: "no such route: #{path}"}]
					end

					::Protocol::HTTP::Response[status,
						{"content-type" => "application/vnd.api+json"},
						[::JSON.dump(body)]]
				end
			end

			let(:firefly) {Client.open("#{bound_url}/api/v1/").authenticated("test-token")}

			def respond(method, path, status: 200, body: {})
				responses[[method, path]] = [status, body]
			end

			after do
				@firefly&.close
			end
		end
	end
end
