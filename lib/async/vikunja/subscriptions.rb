require_relative "page"

module Async
  module Vikunja
    class Subscription < Representation
      def created = self.value[:created]

      def entity = self.value[:entity]

      def entity_id = self.value[:entity_id]

      def id = self.value[:id]
    end

    module Subscriptions
      def subscribe(entity, entity_id) = self.submit(Subscription, self.with(path: "subscriptions/" + Vikunja.escape(entity) + "/" + Vikunja.escape(entity_id)))

      def unsubscribe(entity, entity_id) = self.discard(self.with(path: "subscriptions/" + Vikunja.escape(entity) + "/" + Vikunja.escape(entity_id)))
    end
  end
end
