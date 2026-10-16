require_relative "page"

module Async
  module Vikunja
    class ProjectView < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def view_kind = self.value[:view_kind]

      def position = self.value[:position]

      def project_id = self.value[:project_id]

      def bucket_configuration_mode = self.value[:bucket_configuration_mode]

      def default_bucket_id = self.value[:default_bucket_id]

      def done_bucket_id = self.value[:done_bucket_id]

      def max_permission = self.value[:max_permission]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def filter = self.nested(TaskCollection, self.value[:filter])

      def bucket_configuration = self.nested_list(ProjectViewBucketConfiguration, self.value[:bucket_configuration])

      def buckets(**parameters) = Collection.for(@resource, "buckets", BucketPage, **parameters)

      def tasks(**parameters) = Collection.for(@resource, "tasks", ProjectViewTaskPage, **parameters)

      def buckets_with_tasks(**parameters) = BucketsWithTasks.new(@resource.with(path: "buckets/tasks", parameters: parameters))

      def create_bucket(payload) = self.submit(Bucket, @resource.with(path: "buckets"), payload, identify: true)

      def update_bucket(bucket, payload) = self.submit(Bucket, @resource.with(path: "buckets/" + Vikunja.escape(bucket)), payload, method: :put)

      def remove_bucket(bucket) = self.discard(@resource.with(path: "buckets/" + Vikunja.escape(bucket)))

      def move_task(bucket, payload) = self.submit(TaskBucket, @resource.with(path: "buckets/" + Vikunja.escape(bucket) + "/tasks"), payload, method: :put)

      def update(payload) = self.submit(ProjectView, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(ProjectView, @resource, payload)

      def delete = self.discard(@resource)
    end

    class ProjectViewBucketConfiguration < Representation
      def title = self.value[:title]

      def filter = self.nested(TaskCollection, self.value[:filter])
    end

    class TaskCollection < Representation
      def filter = self.value[:filter]

      def filter_include_nulls = self.value[:filter_include_nulls]

      def s = self.value[:s]

      def sort_by = self.value[:sort_by]

      def order_by = self.value[:order_by]
    end

    class ProjectViewPage < Page
      MEMBER = ProjectView
    end
  end
end
