require_relative "page"

module Async
  module Vikunja
    class TaskComment < Representation
      def id = self.value[:id]

      def comment = self.value[:comment]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def reactions = self.value[:reactions]

      def author = self.nested(User, self.value[:author])

      def max_permission = self.value[:max_permission]

      def update(payload) = self.submit(TaskComment, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(TaskComment, @resource, payload)

      def delete = self.discard(@resource)
    end

    class TaskCommentPage < Page
      MEMBER = TaskComment
    end
  end
end
