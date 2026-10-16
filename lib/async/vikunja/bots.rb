require_relative "page"

module Async
  module Vikunja
    class BotUser < Representation
      def id = self.value[:id]

      def bot_owner_id = self.value[:bot_owner_id]

      def email = self.value[:email]

      def name = self.value[:name]

      def status = self.value[:status]

      def username = self.value[:username]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def max_permission = self.value[:max_permission]

      def update(payload) = self.submit(BotUser, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(BotUser, @resource, payload)

      def delete = self.discard(@resource)
    end

    class BotUserPage < Page
      MEMBER = BotUser
    end

    module Bots
      def bots(**parameters) = Collection.for(self, "user/bots", BotUserPage, **parameters)

      def bot(id) = BotUser.new(self.with(path: "user/bots/" + Vikunja.escape(id)))

      def create_bot(payload) = self.submit(BotUser, self.with(path: "user/bots"), payload, identify: true)
    end
  end
end
