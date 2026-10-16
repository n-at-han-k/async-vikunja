require_relative "page"

module Async
  module Vikunja
    class Session < Representation
      def id = self.value[:id]

      def created = self.value[:created]

      def device_info = self.value[:device_info]

      def ip_address = self.value[:ip_address]

      def last_active = self.value[:last_active]

      def refresh_token = self.value[:refresh_token]
    end

    class SessionPage < Page
      MEMBER = Session
    end

    module Sessions
      def sessions(**parameters) = Collection.for(self, "user/sessions", SessionPage, **parameters)

      def delete_session(id) = self.discard(self.with(path: "user/sessions/" + Vikunja.escape(id)))
    end
  end
end
