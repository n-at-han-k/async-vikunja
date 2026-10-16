require_relative "page"

module Async
  module Vikunja
    class TokenPresets < Representation
      def full = self.value[:full]

      def read_only = self.value[:read_only]

      def typed = self.value[:typed]
    end

    class ConnectionSettings < Representation
      def endpoint = self.value[:endpoint]

      def routes = self.value[:routes]

      def presets = self.nested(TokenPresets, self.value[:presets])
    end

    module MCP
      def mcp_info = ConnectionSettings.new(self.with(path: "mcp/info"))
    end
  end
end
