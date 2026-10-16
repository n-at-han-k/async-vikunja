require_relative "page"

module Async
  module Vikunja
    class SavedFilter < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def description = self.value[:description]

      def is_favorite = self.value[:is_favorite]

      def max_permission = self.value[:max_permission]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def owner = self.nested(User, self.value[:owner])

      def filters = self.nested(TaskCollection, self.value[:filters])

      def favorite? = self.is_favorite == true

      def update(payload) = self.submit(SavedFilter, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(SavedFilter, @resource, payload)

      def delete = self.discard(@resource)
    end

    module Filters
      def filter(id) = SavedFilter.new(self.with(path: "filters/" + Vikunja.escape(id)))

      def create_filter(payload) = self.submit(SavedFilter, self.with(path: "filters"), payload, identify: true)
    end
  end
end
