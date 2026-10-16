require_relative "page"

module Async
  module Vikunja
    module TaskFields
      def id = self.value[:id]

      def title = self.value[:title]

      def description = self.value[:description]

      def identifier = self.value[:identifier]

      def index = self.value[:index]

      def done = self.value[:done]

      def done_at = self.value[:done_at]

      def due_date = self.value[:due_date]

      def start_date = self.value[:start_date]

      def end_date = self.value[:end_date]

      def hex_color = self.value[:hex_color]

      def percent_done = self.value[:percent_done]

      def position = self.value[:position]

      def priority = self.value[:priority]

      def project_id = self.value[:project_id]

      def bucket_id = self.value[:bucket_id]

      def cover_image_attachment_id = self.value[:cover_image_attachment_id]

      def comment_count = self.value[:comment_count]

      def time_entries_count = self.value[:time_entries_count]

      def repeat_after = self.value[:repeat_after]

      def repeat_mode = self.value[:repeat_mode]

      def is_favorite = self.value[:is_favorite]

      def is_unread = self.value[:is_unread]

      def deleted_at = self.value[:deleted_at]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def reactions = self.value[:reactions]

      def related_tasks = self.value[:related_tasks]

      def created_by = self.nested(User, self.value[:created_by])

      def subscription = self.nested(Subscription, self.value[:subscription])

      def assignees = self.nested_list(User, self.value[:assignees])

      def attachments = self.nested_list(TaskAttachment, self.value[:attachments])

      def buckets = self.nested_list(Bucket, self.value[:buckets])

      def comments = self.nested_list(TaskComment, self.value[:comments])

      def labels = self.nested_list(Label, self.value[:labels])

      def reminders = self.nested_list(TaskReminder, self.value[:reminders])

      def done? = self.done == true

      def favorite? = self.is_favorite == true
    end

    class Task < Representation
      include TaskFields

      def task_comments(**parameters) = Collection.for(@resource, "comments", TaskCommentPage, **parameters)

      def task_attachments(**parameters) = Collection.for(@resource, "attachments", TaskAttachmentPage, **parameters)

      def task_labels(**parameters) = Collection.for(@resource, "labels", TaskLabelPage, **parameters)

      def task_assignees(**parameters) = Collection.for(@resource, "assignees", TaskAssigneePage, **parameters)

      def task_time_entries(**parameters) = Collection.for(@resource, "time-entries", TaskTimeEntryPage, **parameters)

      def comment(id) = TaskComment.new(@resource.with(path: "comments/" + Vikunja.escape(id)))

      def attachment(id) = TaskAttachment.new(@resource.with(path: "attachments/" + Vikunja.escape(id)))

      def download_attachment(id) = Download.new(@resource.with(path: "attachments/" + Vikunja.escape(id)))

      def create_comment(payload) = self.submit(TaskComment, @resource.with(path: "comments"), payload, identify: true)

      def upload_attachments(parts) = self.upload(AttachmentUploadResult, @resource.with(path: "attachments"), parts)

      def add_label(label) = self.submit(LabelTask, @resource.with(path: "labels"), {label_id: label})

      def replace_labels(labels) = self.submit(LabelTaskBulk, @resource.with(path: "labels/bulk"), {labels: labels}, method: :put)

      def remove_label(label) = self.discard(@resource.with(path: "labels/" + Vikunja.escape(label)))

      def add_assignee(user) = self.submit(TaskAssginee, @resource.with(path: "assignees"), {user_id: user})

      def replace_assignees(assignees) = self.submit(BulkAssignees, @resource.with(path: "assignees/bulk"), {assignees: assignees}, method: :put)

      def remove_assignee(user) = self.discard(@resource.with(path: "assignees/" + Vikunja.escape(user)))

      def add_relation(payload) = self.submit(TaskRelation, @resource.with(path: "relations"), payload)

      def remove_relation(kind, other) = self.discard(@resource.with(path: "relations/" + Vikunja.escape(kind) + "/" + Vikunja.escape(other)))

      def reposition(payload) = self.submit(TaskPosition, @resource.with(path: "position"), payload, method: :put)

      def mark_read = self.submit(Message, @resource.with(path: "read"), nil, method: :put)

      def duplicate = self.submit(TaskDuplicate, @resource.with(path: "duplicate"))

      def update(payload) = self.submit(Task, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(Task, @resource, payload)

      def delete = self.discard(@resource)
    end

    class TaskReadOneBody < Representation
      include TaskFields

      def max_permission = self.value[:max_permission]
    end

    class TaskReminder < Representation
      def reminder = self.value[:reminder]

      def relative_period = self.value[:relative_period]

      def relative_to = self.value[:relative_to]
    end

    class TaskRelation < Representation
      def task_id = self.value[:task_id]

      def other_task_id = self.value[:other_task_id]

      def relation_kind = self.value[:relation_kind]

      def created = self.value[:created]

      def created_by = self.nested(User, self.value[:created_by])
    end

    class TaskPosition < Representation
      def task_id = self.value[:task_id]

      def project_view_id = self.value[:project_view_id]

      def position = self.value[:position]
    end

    class TaskDuplicate < Representation
      def duplicated_task = self.nested(Task, self.value[:duplicated_task])
    end

    class BulkTaskCreation < Representation
      def tasks = self.nested_list(Task, self.value[:tasks])
    end

    class BulkTask < Representation
      def task_ids = Array(self.value[:task_ids])

      def fields = Array(self.value[:fields])

      def values = self.nested(Task, self.value[:values])

      def tasks = self.nested_list(Task, self.value[:tasks])
    end

    class TaskPage < Page
      MEMBER = Task
    end

    class ProjectTaskPage < TaskPage
      def member_path(record) = "../../../tasks/" + Vikunja.escape(record[:id])
    end

    class ProjectViewTaskPage < TaskPage
      def member_path(record) = "../../../../../tasks/" + Vikunja.escape(record[:id])
    end

    module Tasks
      def tasks(**parameters) = Collection.for(self, "tasks", TaskPage, **parameters)

      def task(id) = Task.new(self.with(path: "tasks/" + Vikunja.escape(id)))

      def update_tasks(payload) = self.submit(BulkTask, self.with(path: "tasks/bulk"), payload, method: :put)
    end
  end
end
