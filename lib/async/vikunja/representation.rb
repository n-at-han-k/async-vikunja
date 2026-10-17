require "async/rest/representation"

require_relative "escape"
require_relative "redacted"
require_relative "submit"
require_relative "wrapper"

module Async
  module Vikunja
    class Representation < Async::REST::Representation[Wrapper]
      include Redacted
      include Submit

      def self.schema = self.name.to_s.split("::").last

      def deconstruct_keys(keys)
        case self.value
        in Hash => value
          value
        else
          {}
        end
      end

      def deconstruct
        case self.value
        in Array => value
          value
        else
          []
        end
      end

      def cacheable?
        cache_control = self.metadata["cache-control"]

        if cache_control
          !cache_control.no_store?
        else
          true
        end
      end

      def nested(klass, value, identify: nil)
        if value
          klass.new(self.identified(@resource, identify, value), value: value, metadata: self.metadata)
        end
      end

      def nested_list(klass, values, identify: nil)
        Array(values).map do |value|
          self.nested(klass, value, identify: identify)
        end
      end
    end

    class PatchRepresentation < Representation
      WRAPPER = MergePatch.new
    end

    class UploadRepresentation < Representation
      WRAPPER = Multipart.new
    end

    class Download < Representation
      WRAPPER = Transfer.new

      def self.open(resource, &block)
        if block
          self.get(resource) do |_resource, response, _klass|
            block.call(response)
          end
        else
          self.new(resource)
        end
      end

      def bytes = self.value

      def media_type
        self.bytes

        self.metadata["content-type"]
      end
    end
  end
end
