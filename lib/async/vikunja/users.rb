require_relative "page"

module Async
  module Vikunja
    class User < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def name = self.value[:name]

      def email = self.value[:email]

      def bot_owner_id = self.value[:bot_owner_id]

      def created = self.value[:created]

      def updated = self.value[:updated]
    end

    class UserInfoBody < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def name = self.value[:name]

      def email = self.value[:email]

      def bot_owner_id = self.value[:bot_owner_id]

      def auth_provider = self.value[:auth_provider]

      def is_admin = self.value[:is_admin]

      def is_local_user = self.value[:is_local_user]

      def deletion_scheduled_at = self.value[:deletion_scheduled_at]

      def pending_email = self.value[:pending_email]

      def settings = self.nested(UserGeneralSettings, self.value[:settings])

      def created = self.value[:created]

      def updated = self.value[:updated]

      def admin? = self.is_admin == true

      def local_user? = self.is_local_user == true
    end

    class UserActionMessageBody < Representation
      def message = self.value[:message]
    end

    class UserExportStatus < Representation
      def id = self.value[:id]

      def created = self.value[:created]

      def expires = self.value[:expires]

      def size = self.value[:size]
    end

    class UserPage < Page
      MEMBER = User
    end

    class UserSearchPage < Page
      MEMBER = User

      def member_resource(record) = @resource
    end

    module Users
      def user = UserInfoBody.new(self.with(path: "user"))

      def users(query) = UserSearchPage.new(self.with(path: "users", parameters: {q: query}))

      def avatar(username, **parameters) = Download.new(self.with(path: "avatar/" + Vikunja.escape(username), parameters: parameters))

      def timezones = Representation.new(self.with(path: "user/timezones"))

      def change_password(old_password:, new_password:) = self.submit(UserActionMessageBody, self.with(path: "user/password"), {old_password: old_password, new_password: new_password})

      def update_email(new_email:, password:) = self.submit(UserActionMessageBody, self.with(path: "user/settings/email"), {new_email: new_email, password: password}, method: :put)

      def cancel_email_update = self.submit(UserActionMessageBody, self.with(path: "user/settings/email"), nil, method: :delete)

      def resend_email_confirmation = self.submit(UserActionMessageBody, self.with(path: "user/settings/email/resend"), nil)

      def export_status = UserExportStatus.new(self.with(path: "user/export"))

      def request_export(password:) = self.submit(Message, self.with(path: "user/export/request"), {password: password})

      def download_export(password:) = self.submit(Download, self.with(path: "user/export/download"), {password: password})

      def request_deletion(password:) = self.discard(self.with(path: "user/deletion/request"), {password: password}, method: :post)

      def confirm_deletion(token:) = self.discard(self.with(path: "user/deletion/confirm"), {token: token}, method: :post)

      def cancel_deletion(password:) = self.discard(self.with(path: "user/deletion/cancel"), {password: password}, method: :post)
    end
  end
end
