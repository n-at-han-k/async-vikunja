# frozen_string_literal: true

module Async
  module Vikunja
    module Environment
      def self.[](name)
        value = ENV[name]

        unless value.nil? || value.empty?
          value
        end
      end

      def self.live?
        !self["VIKUNJA_URL"].nil? && !self["VIKUNJA_TOKEN"].nil?
      end
    end
  end
end
