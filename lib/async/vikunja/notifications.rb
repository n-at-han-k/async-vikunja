require_relative "page"

module Async
  module Vikunja
    class DatabaseNotification < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def notification = self.value[:notification]

      def read_at = self.value[:read_at]

      def created = self.value[:created]
    end

    class DatabaseNotifications < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def notification = self.value[:notification]

      def read = self.value[:read]

      def read_at = self.value[:read_at]

      def created = self.value[:created]
    end

    class NotificationPage < Page
      MEMBER = DatabaseNotification
    end

    module Notifications
      def notifications(**parameters) = Collection.for(self, "notifications", NotificationPage, **parameters)

      def mark_notifications_read = self.submit(Message, self.with(path: "notifications"), nil)

      def clear_notifications = self.discard(self.with(path: "notifications"))

      def update_notification(id, payload) = self.submit(DatabaseNotifications, self.with(path: "notifications/" + Vikunja.escape(id)), payload, method: :put)
    end
  end
end
