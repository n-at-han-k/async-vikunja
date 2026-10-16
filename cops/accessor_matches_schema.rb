require "json"
require "rubocop"

require_relative "support/prism_source"

module RuboCop
  module Cop
    module AsyncVikunja
      class AccessorMatchesSchema < Base
        include PrismSource

        MSG_UNKNOWN = "`%<schema>s` has no property `%<key>s`: this reads a key `%<document>s` does not describe."

        MSG_MISSING = "`%<schema>s` describes %<count>d property this class never reads: %<keys>s."

        MSG_MISSING_MANY = "`%<schema>s` describes %<count>d properties this class never reads: %<keys>s."

        DEFAULT_DOCUMENT_PATH = ::File.expand_path("../data/openapi-v2.json", __dir__)

        REPRESENTATION = /Representation\z/

        READ = /self\.value\[:([A-Za-z_][A-Za-z0-9_]*)\]/

        DIG = /self\.value\.dig\(:([A-Za-z_][A-Za-z0-9_]*)/

        INHERITED = /super\(\)\[:([A-Za-z_][A-Za-z0-9_]*)\]/

        SCHEMA_KEY = "$schema"

        RESERVED = ["value", "metadata", "resource"].freeze

        def on_new_investigation
          self.prism_each(::Prism::ClassNode).each do |node|
            self.check(node)
          end
        end

        private

        def document_path
          cop_config.fetch("DocumentPath", DEFAULT_DOCUMENT_PATH)
        end

        def document
          @document ||= ::JSON.parse(::File.read(self.document_path))
        end

        def schemas
          @schemas ||= self.document.fetch("components", {}).fetch("schemas", {})
        end

        def modules
          @modules ||= self.prism_each(::Prism::ModuleNode).to_h do |node|
            [node.constant_path.slice.split("::").last, node]
          end
        end

        SIBLINGS = ["ReadBody", "ReadOneBody", "Body", "BodyBody"].freeze

        def check(node)
          name = node.constant_path.slice.split("::").last
          properties = self.properties_of(name)

          if self.representation?(node) && !properties.empty?
            self.compare(node, name, properties)
          end
        end

        def allowed_properties(name)
          SIBLINGS.inject(self.properties_of(name)) do |collected, suffix|
            collected | self.properties_of(name + suffix)
          end
        end

        def representation?(node)
          superclass = node.superclass

          !superclass.nil? && REPRESENTATION.match?(superclass.slice)
        end

        def properties_of(name)
          schema = self.schemas.fetch(name, {})

          if schema["type"] == "object"
            schema.fetch("properties", {}).keys - [SCHEMA_KEY]
          else
            []
          end
        end

        def compare(node, name, properties)
          read = self.keys_read(node)

          (read - self.allowed_properties(name)).sort.each do |key|
            add_offense(self.prism_node_range(node.constant_path), message: format(MSG_UNKNOWN, schema: name, key: key, document: self.readable))
          end

          missing = (properties - read - RESERVED).sort

          unless missing.empty?
            add_offense(self.prism_range(node.class_keyword_loc), message: self.missing_message(name, missing))
          end
        end

        def missing_message(name, missing)
          keys = missing.map{|key| "`" + key + "`"}.join(", ")

          if missing.size == 1
            format(MSG_MISSING, schema: name, count: missing.size, keys: keys)
          else
            format(MSG_MISSING_MANY, schema: name, count: missing.size, keys: keys)
          end
        end

        def keys_read(node)
          sources = [node.location.slice].concat(self.included_sources(node))

          sources.flat_map{|source| source.scan(READ) + source.scan(DIG) + source.scan(INHERITED)}.flatten.uniq
        end

        def included_sources(node)
          self.included_modules_of(node).filter_map do |name|
            self.modules[name]&.location&.slice
          end
        end

        def included_modules_of(node)
          self.prism_statements(node.body).filter_map do |statement|
            if self.include_call?(statement)
              statement.arguments.arguments.first.slice.split("::").last
            end
          end
        end

        def include_call?(statement)
          statement.is_a?(::Prism::CallNode) &&
            statement.name == :include &&
            statement.receiver.nil? &&
            statement.arguments &&
            statement.arguments.arguments.size == 1 &&
            statement.arguments.arguments.first.is_a?(::Prism::ConstantReadNode)
        end

        def readable
          self.document_path.delete_prefix(::File.join(Dir.pwd, ""))
        end
      end
    end
  end
end
