# frozen_string_literal: true

require "json"

module Async
  module Vikunja
    module OpenAPI
      DOCUMENT = ::File.expand_path("../../../data/openapi-v2.json", __dir__)

      METHODS = ["get", "post", "put", "patch", "delete", "head", "options"].freeze

      PARAMETER = /\\\{[^}]+\\\}/

      def self.document
        @document ||= ::JSON.parse(::File.read(DOCUMENT))
      end

      def self.version
        document.dig("info", "version")
      end

      def self.prefix
        @prefix ||= document.fetch("servers").first.fetch("url").chomp("/")
      end

      def self.schemas
        @schemas ||= document.fetch("components", {}).fetch("schemas", {})
      end

      def self.schema_for(name)
        found = schemas[name]

        if found && found["type"] == "object" && !properties_of(name).empty?
          found
        end
      end

      def self.properties_of(name)
        schemas.fetch(name, {}).fetch("properties", {}).reject{|key, _| key == "$schema"}
      end

      def self.reference_of(property)
        items = property["items"]

        if property["$ref"]
          [:one, property["$ref"].split("/").last]
        elsif items.is_a?(Hash) && items["$ref"]
          [:many, items["$ref"].split("/").last]
        else
          [nil, nil]
        end
      end

      def self.templates
        @templates ||= document.fetch("paths").keys.to_h do |template|
          pattern = ::Regexp.escape(prefix + template).gsub(PARAMETER, "[^/]+")

          [template, ::Regexp.new("\\A" + pattern + "\\z")]
        end
      end

      def self.route_for(method, path)
        path = path.split("?", 2).first
        unless path == "/"
          path = path.chomp("/")
        end

        found = templates.find do |template, pattern|
          pattern.match?(path) && document.dig("paths", template).key?(method.to_s.downcase)
        end

        found&.first
      end

      def self.documented?(method, path)
        !route_for(method, path).nil?
      end

      def self.operation(method, path)
        template = route_for(method, path)

        if template
          document.dig("paths", template, method.to_s.downcase)
        end
      end

      def self.security_for(method, path)
        found = operation(method, path)

        if found
          found.fetch("security", document.fetch("security", []))
        end
      end

      def self.routes
        document.fetch("paths").flat_map do |template, operations|
          operations.keys.select{|key| METHODS.include?(key)}.map do |method|
            [method.upcase, prefix + template]
          end
        end
      end
    end
  end
end
