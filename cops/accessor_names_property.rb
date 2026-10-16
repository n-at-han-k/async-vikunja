require "rubocop"

require_relative "support/prism_source"

module RuboCop
  module Cop
    module AsyncVikunja
      class AccessorNamesProperty < Base
        include PrismSource

        MSG = "`%<name>s` reads the property `%<key>s`: name the accessor after the property it reads, or read the property it is named after."

        READ = /self\.value\[:([A-Za-z_][A-Za-z0-9_]*)\]/

        INHERITED = /super\(\)\[:([A-Za-z_][A-Za-z0-9_]*)\]/

        def on_new_investigation
          self.prism_each(::Prism::DefNode).each do |node|
            self.check(node)
          end
        end

        private

        def check(node)
          keys = (node.location.slice.scan(READ) + node.location.slice.scan(INHERITED)).flatten.uniq

          if self.accessor?(node) && keys.size == 1 && keys.first != node.name.to_s
            add_offense(self.prism_range(node.name_loc), message: format(MSG, name: node.name, key: keys.first))
          end
        end

        def accessor?(node)
          node.parameters.nil? && !node.name.to_s.end_with?("?", "=", "!")
        end
      end
    end
  end
end
