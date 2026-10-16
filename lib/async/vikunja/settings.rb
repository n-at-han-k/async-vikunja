require_relative "page"

module Async
  module Vikunja
    class UserGeneralSettings < Representation
      def default_project_id = self.value[:default_project_id]

      def discoverable_by_email = self.value[:discoverable_by_email]

      def discoverable_by_name = self.value[:discoverable_by_name]

      def email_reminders_enabled = self.value[:email_reminders_enabled]

      def extra_settings_links = self.value[:extra_settings_links]

      def frontend_settings = self.value[:frontend_settings]

      def language = self.value[:language]

      def name = self.value[:name]

      def overdue_tasks_reminders_enabled = self.value[:overdue_tasks_reminders_enabled]

      def overdue_tasks_reminders_time = self.value[:overdue_tasks_reminders_time]

      def timezone = self.value[:timezone]

      def week_start = self.value[:week_start]
    end

    class UserAvatarProviderBody < Representation
      def avatar_provider = self.value[:avatar_provider]
    end

    class TOTP < Representation
      def enabled = self.value[:enabled]

      def secret = self.value[:secret]

      def url = self.value[:url]

      def enabled? = self.enabled == true
    end

    module Settings
      def settings = UserGeneralSettings.new(self.with(path: "user/settings/general"))

      def update_settings(payload) = self.submit(UserActionMessageBody, self.with(path: "user/settings/general"), payload, method: :put)

      def patch_settings(payload) = self.merge_patch(UserActionMessageBody, self.with(path: "user/settings/general"), payload)

      def avatar_provider = UserAvatarProviderBody.new(self.with(path: "user/settings/avatar/provider"))

      def set_avatar_provider(avatar_provider:) = self.submit(UserAvatarProviderBody, self.with(path: "user/settings/avatar/provider"), {avatar_provider: avatar_provider}, method: :put)

      def patch_avatar_provider(payload) = self.merge_patch(UserAvatarProviderBody, self.with(path: "user/settings/avatar/provider"), payload)

      def upload_avatar(part) = self.upload(Message, self.with(path: "user/settings/avatar"), [part], method: :put)

      def totp = TOTP.new(self.with(path: "user/settings/totp"))

      def enroll_totp = self.submit(TOTP, self.with(path: "user/settings/totp/enroll"), nil)

      def enable_totp(passcode:) = self.submit(Message, self.with(path: "user/settings/totp/enable"), {passcode: passcode})

      def disable_totp(password:) = self.submit(Message, self.with(path: "user/settings/totp/disable"), {password: password})

      def totp_qrcode = Download.new(self.with(path: "user/settings/totp/qrcode"))
    end
  end
end
