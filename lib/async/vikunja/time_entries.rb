require_relative "page"

module Async
  module Vikunja
    class TimeEntry < Representation
      def id = self.value[:id]

      def comment = self.value[:comment]

      def start_time = self.value[:start_time]

      def end_time = self.value[:end_time]

      def project_id = self.value[:project_id]

      def task_id = self.value[:task_id]

      def user_id = self.value[:user_id]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def max_permission = self.value[:max_permission]

      def update(payload) = self.submit(TimeEntry, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(TimeEntry, @resource, payload)

      def delete = self.discard(@resource)
    end

    class TimeEntryPage < Page
      MEMBER = TimeEntry
    end

    class ProjectTimeEntryPage < TimeEntryPage
      def member_path(record) = "../../../time-entries/" + Vikunja.escape(record[:id])
    end

    class TaskTimeEntryPage < TimeEntryPage
      def member_path(record) = "../../../time-entries/" + Vikunja.escape(record[:id])
    end

    module TimeEntries
      def time_entries(**parameters) = Collection.for(self, "time-entries", TimeEntryPage, **parameters)

      def time_entry(id) = TimeEntry.new(self.with(path: "time-entries/" + Vikunja.escape(id)))

      def create_time_entry(payload) = self.submit(TimeEntry, self.with(path: "time-entries"), payload, identify: true)

      def stop_timer = self.submit(TimeEntry, self.with(path: "time-entries/timer/stop"), nil)
    end
  end
end
