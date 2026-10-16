# frozen_string_literal: true

require "sus/fixtures/async/reactor_context"

require "async/vikunja/openapi"
require "async/vikunja/environment"
require "async/vikunja/client"

module Async
  module Vikunja
    LiveContext = Sus::Shared("a live vikunja") do
      include Sus::Fixtures::Async::ReactorContext

      let(:url) {Environment["VIKUNJA_URL"]}

      let(:token) {Environment["VIKUNJA_TOKEN"]}

      let(:vikunja) do
        unless url && token
          skip "set VIKUNJA_URL and VIKUNJA_TOKEN: eval \"$(bin/vikunja-bootstrap)\""
        end

        Client.open(url).authenticated(token)
      end

      after do
        @vikunja&.close
      end

      def unique(prefix)
        prefix + "-" + Process.pid.to_s + "-" + Process.clock_gettime(Process::CLOCK_MONOTONIC).to_s
      end
    end
  end
end
