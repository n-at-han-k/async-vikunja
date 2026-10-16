require "protocol/url/encoding"

module Async
  module Vikunja
    def self.escape(value)
      ::Protocol::URL::Encoding.escape(value.to_s)
    end
  end
end
