require_relative "page"

module Async
  module Vikunja
    class LocalAuthInfo < Representation
      def enabled = self.value[:enabled]

      def registration_enabled = self.value[:registration_enabled]
    end

    class LdapAuthInfo < Representation
      def enabled = self.value[:enabled]
    end

    class Provider < Representation
      def auth_url = self.value[:auth_url]

      def client_id = self.value[:client_id]

      def email_fallback = self.value[:email_fallback]

      def force_user_info = self.value[:force_user_info]

      def key = self.value[:key]

      def logout_url = self.value[:logout_url]

      def name = self.value[:name]

      def scope = self.value[:scope]

      def username_fallback = self.value[:username_fallback]
    end

    class OpenIDAuthInfo < Representation
      def enabled = self.value[:enabled]

      def providers = self.nested_list(Provider, self.value[:providers])
    end

    class AuthInfo < Representation
      def ldap = self.nested(LdapAuthInfo, self.value[:ldap])

      def local = self.nested(LocalAuthInfo, self.value[:local])

      def openid_connect = self.nested(OpenIDAuthInfo, self.value[:openid_connect])
    end

    class LegalInfo < Representation
      def imprint_url = self.value[:imprint_url]

      def privacy_policy_url = self.value[:privacy_policy_url]
    end

    class VikunjaInfos < Representation
      def allow_icon_changes = self.value[:allow_icon_changes]

      def auth = self.nested(AuthInfo, self.value[:auth])

      def available_migrators = self.value[:available_migrators]

      def caldav_enabled = self.value[:caldav_enabled]

      def concurrent_writes = self.value[:concurrent_writes]

      def demo_mode_enabled = self.value[:demo_mode_enabled]

      def email_reminders_enabled = self.value[:email_reminders_enabled]

      def enabled_background_providers = self.value[:enabled_background_providers]

      def enabled_pro_features = self.value[:enabled_pro_features]

      def frontend_url = self.value[:frontend_url]

      def legal = self.nested(LegalInfo, self.value[:legal])

      def link_sharing_enabled = self.value[:link_sharing_enabled]

      def max_file_size = self.value[:max_file_size]

      def max_items_per_page = self.value[:max_items_per_page]

      def motd = self.value[:motd]

      def public_teams_enabled = self.value[:public_teams_enabled]

      def task_attachments_enabled = self.value[:task_attachments_enabled]

      def task_comments_enabled = self.value[:task_comments_enabled]

      def totp_enabled = self.value[:totp_enabled]

      def user_deletion_enabled = self.value[:user_deletion_enabled]

      def version = self.value[:version]

      def webhooks_enabled = self.value[:webhooks_enabled]
    end

    class ProviderStatus < Representation
      def available = self.value[:available]

      def key = self.value[:key]
    end

    class Health < Representation
      def self.schema = "HealthBodyBody"

      def openid_providers = self.nested_list(ProviderStatus, self.value[:openid_providers])

      def status = self.value[:status]

      def ok? = self.status == "OK"
    end

    class RouteDetail < Representation
      def method = self.value[:method]

      def path = self.value[:path]
    end

    class Message < Representation
      def message = self.value[:message]
    end

    module Service
      def info = VikunjaInfos.new(self.with(path: "info"))

      def health = Health.new(self.with(path: "health"))

      def routes = Representation.new(self.with(path: "routes"))

      def notifications_atom(&block) = Download.open(self.with(path: "notifications.atom"), &block)
    end
  end
end
