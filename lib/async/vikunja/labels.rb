require_relative "page"

module Async
  module Vikunja
    class Label < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def description = self.value[:description]

      def hex_color = self.value[:hex_color]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])

      def max_permission = self.value[:max_permission]

      def update(payload) = self.submit(Label, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(Label, @resource, payload)

      def delete = self.discard(@resource)
    end

    class LabelWithTaskID < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def description = self.value[:description]

      def hex_color = self.value[:hex_color]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])
    end

    class LabelTask < Representation
      def label_id = self.value[:label_id]

      def created = self.value[:created]
    end

    class LabelTaskBulk < Representation
      def labels = self.nested_list(Label, self.value[:labels])
    end

    class LabelPage < Page
      MEMBER = LabelWithTaskID
    end

    class TaskLabelPage < Page
      MEMBER = LabelWithTaskID
    end

    module Labels
      def labels(**parameters) = Collection.for(self, "labels", LabelPage, **parameters)

      def label(id) = Label.new(self.with(path: "labels/" + Vikunja.escape(id)))

      def create_label(payload) = self.submit(Label, self.with(path: "labels"), payload, identify: true)
    end
  end
end
