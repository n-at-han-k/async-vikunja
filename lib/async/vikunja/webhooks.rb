require_relative "page"

module Async
  module Vikunja
    class Webhook < Representation
      def id = self.value[:id]

      def target_url = self.value[:target_url]

      def events = self.value[:events]

      def project_id = self.value[:project_id]

      def user_id = self.value[:user_id]

      def secret = self.value[:secret]

      def basic_auth_user = self.value[:basic_auth_user]

      def basic_auth_password = self.value[:basic_auth_password]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])

      def update(payload) = self.submit(Webhook, @resource, payload, method: :put)

      def delete = self.discard(@resource)
    end

    class ProjectWebhookPage < Page
      MEMBER = Webhook
    end

    class UserWebhookPage < Page
      MEMBER = Webhook
    end

    module Webhooks
      def webhook_events = Representation.new(self.with(path: "webhooks/events"))

      def webhooks(**parameters) = Collection.for(self, "user/settings/webhooks", UserWebhookPage, **parameters)

      def create_webhook(payload) = self.submit(Webhook, self.with(path: "user/settings/webhooks"), payload, identify: true)

      def update_webhook(webhook, payload) = self.submit(Webhook, self.with(path: "user/settings/webhooks/" + Vikunja.escape(webhook)), payload, method: :put)

      def remove_webhook(webhook) = self.discard(self.with(path: "user/settings/webhooks/" + Vikunja.escape(webhook)))

      def user_webhook_events = Representation.new(self.with(path: "user/settings/webhooks/events"))
    end
  end
end
