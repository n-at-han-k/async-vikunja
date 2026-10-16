require_relative "page"

module Async
  module Vikunja
    class APIToken < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def owner_id = self.value[:owner_id]

      def permissions = self.value[:permissions]

      def expires_at = self.value[:expires_at]

      def created = self.value[:created]

      def token = self.value[:token]

      def delete = self.discard(@resource)
    end

    class Token < Representation
      def id = self.value[:id]

      def created = self.value[:created]

      def token = self.value[:token]

      def delete = self.discard(@resource)
    end

    class APITokenPage < Page
      MEMBER = APIToken
    end

    class CaldavTokenPage < Page
      MEMBER = Token
    end

    module Tokens
      def tokens(**parameters) = Collection.for(self, "tokens", APITokenPage, **parameters)

      def create_token(payload) = self.submit(APIToken, self.with(path: "tokens"), payload, identify: true)

      def delete_token(id) = self.discard(self.with(path: "tokens/" + Vikunja.escape(id)))

      def test_token = Message.new(self.with(path: "token/test"))

      def check_token = self.submit(Message, self.with(path: "token/test"), nil)

      def caldav_tokens(**parameters) = Collection.for(self, "user/settings/token/caldav", CaldavTokenPage, **parameters)

      def create_caldav_token = self.submit(Token, self.with(path: "user/settings/token/caldav"), nil, identify: true)

      def delete_caldav_token(id) = self.discard(self.with(path: "user/settings/token/caldav/" + Vikunja.escape(id)))
    end
  end
end
