require_relative "page"
require_relative "users"

module Async
  module Vikunja
    class TaskAssginee < Representation
      def user_id = self.value[:user_id]

      def created = self.value[:created]
    end

    class BulkAssignees < Representation
      def assignees = self.nested_list(User, self.value[:assignees])
    end

    class TaskAssigneePage < Page
      MEMBER = User
    end
  end
end
