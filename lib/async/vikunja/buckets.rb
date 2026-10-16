require_relative "page"

module Async
  module Vikunja
    class Bucket < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def limit = self.value[:limit]

      def position = self.value[:position]

      def count = self.value[:count]

      def project_view_id = self.value[:project_view_id]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])

      def tasks = self.nested_list(Task, self.value[:tasks])
    end

    class TaskBucket < Representation
      def task_id = self.value[:task_id]

      def bucket_id = self.value[:bucket_id]

      def project_view_id = self.value[:project_view_id]

      def task = self.nested(Task, self.value[:task])

      def bucket = self.nested(Bucket, self.value[:bucket])
    end

    class BucketsWithTasks < Representation
      def self.schema = "BucketsWithTasksBodyBody"

      def total = self.value[:total]

      def items = self.nested_list(Bucket, self.value[:items])
    end

    class BucketPage < Page
      MEMBER = Bucket
    end
  end
end
