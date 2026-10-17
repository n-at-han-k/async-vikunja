require_relative "page"

module Async
  module Vikunja
    class File < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def mime = self.value[:mime]

      def size = self.value[:size]

      def created = self.value[:created]
    end

    class TaskAttachment < Representation
      def id = self.value[:id]

      def task_id = self.value[:task_id]

      def created = self.value[:created]

      def created_by = self.nested(User, self.value[:created_by])

      def file = self.nested(File, self.value[:file])

      def download(&block) = Download.open(@resource, &block)

      def preview(size, &block) = Download.open(@resource.with(parameters: {preview_size: size}), &block)

      def delete = self.discard(@resource)
    end

    class AttachmentUploadError < Representation
      def code = self.value[:code]

      def message = self.value[:message]
    end

    class AttachmentUploadResult < Representation
      def success = self.nested_list(TaskAttachment, self.value[:success], identify: true)

      def errors = self.nested_list(AttachmentUploadError, self.value[:errors])
    end

    class TaskAttachmentPage < Page
      MEMBER = TaskAttachment
    end
  end
end
