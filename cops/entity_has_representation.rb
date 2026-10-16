# frozen_string_literal: true

require "json"
require "prism"
require "rubocop"
require "set"

module RuboCop
  module Cop
    module AsyncVikunja
      class EntityHasRepresentation < Base
        MSG = "`%<entity>s` is an entity of the API with no representation: add `class %<entity>s < Representation` under `lib`, or name it under `Pending` until it is written."

        MSG_UNKNOWN = "`%<entity>s` is listed under `Pending` but is not an entity of `%<document>s`: remove it."

        DEFAULT_DOCUMENT_PATH = File.expand_path("../data/openapi-v2.json", __dir__)

        ENVELOPE = /\APaginated/

        GENERATED = /(?:BodyBody|ReadBody)\z/

        REPRESENTATION = /Representation\z/

        SUCCESS = /\A2\d\d\z/

        def on_new_investigation
          path = processed_source.file_path

          if path
            library = self.library_for(path)

            if library
              self.check_entities(library)
            end
          end
        end

        private

        def document_path
          cop_config.fetch("DocumentPath", DEFAULT_DOCUMENT_PATH)
        end

        def document
          @document ||= ::JSON.parse(File.read(self.document_path))
        end

        def schemas
          @schemas ||= self.document.fetch("components", {}).fetch("schemas", {})
        end

        def pending
          cop_config.fetch("Pending", [])
        end

        def library_for(path)
          absolute = File.expand_path(path)
          segments = absolute.split(File::SEPARATOR)

          index = segments.rindex("lib")

          if index
            File.join(segments[0..index])
          end
        end

        def check_entities(library)
          written = self.representations_in(library)
          entities = self.entities

          entities.each do |entity|
            covered = written.include?(entity) || self.pending.include?(entity)

            unless covered
              add_global_offense(format(MSG, entity: entity))
            end
          end

          self.pending.each do |entity|
            unless entities.include?(entity)
              add_global_offense(format(MSG_UNKNOWN, entity: entity, document: self.readable))
            end
          end
        end

        def representations_in(library)
          found = Dir.glob(File.join(library, "**", "*.rb")).flat_map do |file|
            self.representations_of(::Prism.parse_file(file).value)
          end

          found.to_set
        end

        def representations_of(root)
          self.classes_of(root).filter_map do |node|
            superclass = node.superclass

            if superclass && REPRESENTATION.match?(superclass.slice)
              node.constant_path.slice.split("::").last
            end
          end
        end

        def classes_of(root)
          [].tap do |collected|
            frontier = [root]

            until frontier.empty?
              node = frontier.shift

              if node.is_a?(::Prism::ClassNode)
                collected << node
              end

              frontier.concat(node.compact_child_nodes)
            end
          end
        end

        def entities
          @entities ||= self.collect_entities
        end

        def collect_entities
          selected = self.answered_schemas.select do |name|
            self.entity?(name)
          end

          selected.sort
        end

        def entity?(name)
          schema = self.schemas.fetch(name, {})
          properties = schema.fetch("properties", {}).keys - ["$schema"]

          named = !ENVELOPE.match?(name) && !GENERATED.match?(name)

          named && schema["type"] == "object" && !properties.empty?
        end

        def answered_schemas
          Set.new.tap do |reached|
            frontier = self.response_schemas.to_a

            until frontier.empty?
              name = frontier.shift

              unless reached.include?(name) || !self.schemas.key?(name)
                reached << name
                frontier.concat(self.references_in(self.schemas.fetch(name)).to_a)
              end
            end
          end
        end

        def response_schemas
          Set.new.tap do |found|
            self.document.fetch("paths", {}).each_value do |operations|
              operations.each_value do |operation|
                self.collect_responses(operation, found)
              end
            end
          end
        end

        def collect_responses(operation, found)
          if operation.is_a?(Hash)
            operation.fetch("responses", {}).each do |status, response|
              if SUCCESS.match?(status)
                found.merge(self.references_in(response))
              end
            end
          end
        end

        def references_in(node)
          Set.new.tap do |found|
            frontier = [node]

            until frontier.empty?
              current = frontier.shift

              if current.is_a?(Hash)
                reference = current["$ref"]

                if reference.is_a?(String)
                  found << reference.split("/").last
                end

                frontier.concat(current.values)
              elsif current.is_a?(Array)
                frontier.concat(current)
              end
            end
          end
        end

        def readable
          self.document_path.delete_prefix(File.join(Dir.pwd, ""))
        end
      end
    end
  end
end
