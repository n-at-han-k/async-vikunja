require "async/rest/resource"

require_relative "admin"
require_relative "assignees"
require_relative "attachments"
require_relative "auth"
require_relative "bots"
require_relative "buckets"
require_relative "comments"
require_relative "error"
require_relative "filters"
require_relative "labels"
require_relative "migration"
require_relative "notifications"
require_relative "page"
require_relative "projects"
require_relative "reactions"
require_relative "service"
require_relative "sessions"
require_relative "settings"
require_relative "sharing"
require_relative "subscriptions"
require_relative "submit"
require_relative "tasks"
require_relative "teams"
require_relative "time_entries"
require_relative "tokens"
require_relative "users"
require_relative "version"
require_relative "views"
require_relative "webhooks"

module Async
  module Vikunja
    class Client < Async::REST::Resource
      ENDPOINT = Async::HTTP::Endpoint.parse(ENV.fetch("VIKUNJA_URL", "http://localhost:3456/api/v2/"))

      USER_AGENT = "async-vikunja (https://github.com/n-at-han-k/async-vikunja, v" + VERSION + ")"

      include Submit

      include Admin
      include Auth
      include Bots
      include Filters
      include Labels
      include Migration
      include Notifications
      include Projects
      include Reactions
      include Service
      include Sessions
      include Settings
      include Sharing
      include Subscriptions
      include Tasks
      include Teams
      include TimeEntries
      include Tokens
      include Users
      include Webhooks

      def initialize(delegate, reference = ::Protocol::URL::Reference.parse, headers = ::Protocol::HTTP::Headers.new)
        super

        unless @headers["user-agent"]
          @headers = @headers.merge("user-agent" => USER_AGENT)
        end
      end

      def authenticated(token)
        self.with(headers: {"authorization" => "Bearer " + token})
      end
    end
  end
end
