# frozen_string_literal: true

require "sus/fixtures/async/http/server_context"
require "protocol/url"

require "async/vikunja/openapi"
require "async/vikunja/client"

module Async
  module Vikunja
    TOKEN = "tk_0000000000000000000000000000000000000000"

    ServerContext = Sus::Shared("a vikunja server") do
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
            route: OpenAPI.route_for(request.method, path),
            query: query && ::Protocol::URL::Encoding.decode(query, symbolize_keys: true),
            headers: request.headers.to_h,
            payload: request.body&.join,
          }

          status, body, extra = canned.fetch([request.method, path]) do
            [404, {message: "no such route: " + path}, {}]
          end

          case body
          when ::String
            chunk = body
          else
            chunk = ::JSON.dump(body)
          end

          ::Protocol::HTTP::Response[status,
            {"content-type" => "application/json"}.merge(extra || {}),
            [chunk]]
        end
      end

      let(:vikunja) {Client.open(bound_url.to_s + "/api/v2/").authenticated(TOKEN)}

      def respond(method, path, status: 200, body: {}, headers: {})
        unless OpenAPI.documented?(method, path)
          raise ArgumentError, "no " + method + " " + path + " in OpenAPI " + OpenAPI.version
        end

        responses[[method, path]] = [status, body, headers]
      end

      def undocumented_requests
        requests.reject{|request| request[:route]}
      end

      after do
        @vikunja&.close
      end
    end
  end
end
