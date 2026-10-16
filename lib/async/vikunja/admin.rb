require_relative "page"

module Async
  module Vikunja
    class Info < Representation
      def instance_id = self.value[:instance_id]

      def licensed = self.value[:licensed]

      def last_check_failed = self.value[:last_check_failed]

      def features = self.value[:features]

      def max_users = self.value[:max_users]

      def expires_at = self.value[:expires_at]

      def validated_at = self.value[:validated_at]
    end

    class ShareCounts < Representation
      def link_shares = self.value[:link_shares]

      def team_shares = self.value[:team_shares]

      def user_shares = self.value[:user_shares]
    end

    class Overview < Representation
      def projects = self.value[:projects]

      def tasks = self.value[:tasks]

      def teams = self.value[:teams]

      def users = self.value[:users]

      def license = self.nested(Info, self.value[:license])

      def shares = self.nested(ShareCounts, self.value[:shares])
    end

    class AdminUser < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def name = self.value[:name]

      def email = self.value[:email]

      def is_admin = self.value[:is_admin]

      def status = self.value[:status]

      def issuer = self.value[:issuer]

      def subject = self.value[:subject]

      def auth_provider = self.value[:auth_provider]

      def bot_owner_id = self.value[:bot_owner_id]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def admin? = self.is_admin == true
    end

    class AdminUserPage < Page
      MEMBER = AdminUser
    end

    module Admin
      def admin_overview = Overview.new(self.with(path: "admin/overview"))

      def admin_projects(**parameters) = Collection.for(self, "admin/projects", AdminProjectPage, **parameters)

      def set_project_owner(id, payload) = self.submit(Project, self.with(path: "admin/projects/" + Vikunja.escape(id) + "/owner"), payload, method: :patch)

      def admin_users(**parameters) = Collection.for(self, "admin/users", AdminUserPage, **parameters)

      def create_admin_user(payload) = self.submit(AdminUser, self.with(path: "admin/users"), payload, identify: true)

      def remove_admin_user(id, **parameters) = self.discard(self.with(path: "admin/users/" + Vikunja.escape(id), parameters: parameters))

      def set_admin(id, payload) = self.submit(AdminUser, self.with(path: "admin/users/" + Vikunja.escape(id) + "/admin"), payload, method: :patch)

      def set_user_password(id, payload) = self.submit(AdminUser, self.with(path: "admin/users/" + Vikunja.escape(id) + "/password"), payload, method: :patch)

      def set_user_status(id, payload) = self.submit(AdminUser, self.with(path: "admin/users/" + Vikunja.escape(id) + "/status"), payload, method: :patch)

      def send_password_reset_email(id) = self.submit(Message, self.with(path: "admin/users/" + Vikunja.escape(id) + "/password-reset-email"), nil)
    end
  end
end
