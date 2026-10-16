require "rubocop"

require_relative "support/prism_source"

module RuboCop
  module Cop
    module AsyncVikunja
      class CreateIdentifiesResource < Base
        include PrismSource

        MSG = "`%<name>s` submits a creation without saying what identifies what it created: pass `identify: true` to name it under the collection it was posted to, `identify: \"../\"` to name it elsewhere, or `identify: nil` when the API publishes no identifier for it."

        CREATE = /\Acreate/

        SUBMIT = :submit

        IDENTIFY = :identify

        def on_new_investigation
          self.prism_each(::Prism::DefNode).each do |node|
            self.check(node)
          end
        end

        private

        def check(node)
          if CREATE.match?(node.name.to_s)
            self.submissions_in(node).each do |call|
              unless self.identifies?(call)
                add_offense(self.prism_range(node.name_loc), message: format(MSG, name: node.name))
              end
            end
          end
        end

        def submissions_in(node)
          self.prism_descendants(node, ::Prism::CallNode).select do |call|
            call.name == SUBMIT
          end
        end

        def identifies?(call)
          arguments = call.arguments

          if arguments.nil?
            false
          else
            self.keywords_of(arguments).include?(IDENTIFY)
          end
        end

        def keywords_of(arguments)
          arguments.arguments.flat_map do |argument|
            if argument.is_a?(::Prism::KeywordHashNode)
              argument.elements.filter_map{|element| self.key_of(element)}
            else
              []
            end
          end
        end

        def key_of(element)
          if element.is_a?(::Prism::AssocNode) && element.key.is_a?(::Prism::SymbolNode)
            element.key.unescaped.to_sym
          end
        end
      end
    end
  end
end
