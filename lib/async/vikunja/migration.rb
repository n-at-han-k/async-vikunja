require_relative "page"

module Async
  module Vikunja
    class ColumnMapping < Representation
      def attribute = self.value[:attribute]

      def column_index = self.value[:column_index]

      def column_name = self.value[:column_name]
    end

    class DetectionResult < Representation
      def columns = self.value[:columns]

      def date_format = self.value[:date_format]

      def delimiter = self.value[:delimiter]

      def preview_rows = self.value[:preview_rows]

      def quote_char = self.value[:quote_char]

      def suggested_mapping = self.nested_list(ColumnMapping, self.value[:suggested_mapping])
    end

    class PreviewTask < Representation
      def title = self.value[:title]

      def description = self.value[:description]

      def done = self.value[:done]

      def due_date = self.value[:due_date]

      def start_date = self.value[:start_date]

      def end_date = self.value[:end_date]

      def labels = self.value[:labels]

      def priority = self.value[:priority]

      def project = self.value[:project]
    end

    class PreviewResult < Representation
      def tasks = self.nested_list(PreviewTask, self.value[:tasks])

      def total_rows = self.value[:total_rows]
    end

    class Status < Representation
      def id = self.value[:id]

      def migrator_name = self.value[:migrator_name]

      def started_at = self.value[:started_at]

      def finished_at = self.value[:finished_at]

      def error_kind = self.value[:error_kind]

      def error_message = self.value[:error_message]

      def failed? = !self.error_kind.nil?
    end

    module Migration
      def csv_detect(part) = self.upload(DetectionResult, self.with(path: "migration/csv/detect"), [part])

      def csv_preview(parts) = self.upload(PreviewResult, self.with(path: "migration/csv/preview"), parts)

      def csv_migrate(parts) = self.upload(Message, self.with(path: "migration/csv/migrate"), parts)

      def csv_status = Status.new(self.with(path: "migration/csv/status"))

      def planka_migrate(payload) = self.submit(Message, self.with(path: "migration/planka/migrate"), payload)

      def planka_status = Status.new(self.with(path: "migration/planka/status"))

      def ticktick_migrate(part) = self.upload(Message, self.with(path: "migration/ticktick/migrate"), [part])

      def ticktick_status = Status.new(self.with(path: "migration/ticktick/status"))

      def vikunja_file_migrate(part) = self.upload(Message, self.with(path: "migration/vikunja-file/migrate"), [part])

      def vikunja_file_status = Status.new(self.with(path: "migration/vikunja-file/status"))

      def wekan_migrate(part) = self.upload(Message, self.with(path: "migration/wekan/migrate"), [part])

      def wekan_status = Status.new(self.with(path: "migration/wekan/status"))
    end
  end
end
