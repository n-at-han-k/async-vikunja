require_relative "page"

module Async
  module Vikunja
    class LinkSharing < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def hash = self.value[:hash]

      def password = self.value[:password]

      def permission = self.value[:permission]

      def sharing_type = self.value[:sharing_type]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def shared_by = self.nested(User, self.value[:shared_by])
    end

    class LinkShareToken < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def hash = self.value[:hash]

      def password = self.value[:password]

      def permission = self.value[:permission]

      def project_id = self.value[:project_id]

      def sharing_type = self.value[:sharing_type]

      def token = self.value[:token]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def shared_by = self.nested(User, self.value[:shared_by])
    end

    class ProjectUser < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def permission = self.value[:permission]

      def created = self.value[:created]

      def updated = self.value[:updated]
    end

    class TeamProject < Representation
      def id = self.value[:id]

      def team_id = self.value[:team_id]

      def permission = self.value[:permission]

      def created = self.value[:created]

      def updated = self.value[:updated]
    end

    class TeamWithPermission < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def description = self.value[:description]

      def is_public = self.value[:is_public]

      def external_id = self.value[:external_id]

      def permission = self.value[:permission]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])

      def members = self.nested_list(TeamUser, self.value[:members])
    end

    class UserWithPermission < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def name = self.value[:name]

      def email = self.value[:email]

      def permission = self.value[:permission]

      def bot_owner_id = self.value[:bot_owner_id]

      def created = self.value[:created]

      def updated = self.value[:updated]
    end

    class LinkSharingPage < Page
      MEMBER = LinkSharing
    end

    class TeamWithPermissionPage < Page
      MEMBER = TeamWithPermission
    end

    class ProjectUserPage < Page
      MEMBER = UserWithPermission

      def member_path(record) = Vikunja.escape(record[:username])
    end

    module Sharing
      def authenticate_share(share, payload = {}) = self.submit(LinkShareToken, self.with(path: "shares/" + Vikunja.escape(share) + "/auth"), payload)
    end
  end
end
