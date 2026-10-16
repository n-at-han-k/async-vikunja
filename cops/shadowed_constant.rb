require "prism"
require "rubocop"
require "set"

require_relative "support/prism_source"

module RuboCop
  module Cop
    module AsyncVikunja
      class ShadowedConstant < Base
        include PrismSource
        extend AutoCorrector

        MSG = "`%<name>s` names a class of this library as well as a top-level one: write `::%<name>s` for the top-level class, or `Vikunja::%<name>s` for this one."

        DEFAULT_LIBRARY_PATH = ::File.expand_path("../lib", __dir__)

        def on_new_investigation
          self.prism_each(::Prism::ConstantReadNode).each do |node|
            self.check(node)
          end
        end

        private

        def library_path
          cop_config.fetch("LibraryPath", DEFAULT_LIBRARY_PATH)
        end

        def shadowed
          @shadowed ||= self.collect_shadowed
        end

        def collect_shadowed
          names = Dir.glob(::File.join(self.library_path, "**", "*.rb")).flat_map do |file|
            self.classes_in(::Prism.parse_file(file).value)
          end

          names.select{|name| ::Object.const_defined?(name)}.to_set
        end

        def classes_in(root)
          [].tap do |collected|
            frontier = [root]

            until frontier.empty?
              node = frontier.shift

              if node.is_a?(::Prism::ClassNode)
                collected << node.constant_path.slice.split("::").last
              end

              frontier.concat(node.compact_child_nodes)
            end
          end
        end

        def check(node)
          if self.shadowed.include?(node.name.to_s) && self.receiver?(node)
            range = self.prism_node_range(node)

            add_offense(range, message: format(MSG, name: node.name)) do |corrector|
              corrector.replace(range, "::" + node.name.to_s)
            end
          end
        end

        def receiver?(node)
          parent = self.prism_parent(node)

          parent.is_a?(::Prism::CallNode) && parent.receiver.equal?(node)
        end
      end
    end
  end
end
