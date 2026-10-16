require_relative "page"

module Async
  module Vikunja
    class InviteLinkTeam < Representation
      def id = self.value[:id]

      def name = self.value[:name]
    end

    class UserInviteLink < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def token = self.value[:token]

      def max_uses = self.value[:max_uses]

      def uses = self.value[:uses]

      def expires_at = self.value[:expires_at]

      def skip_email_confirm = self.value[:skip_email_confirm]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])

      def teams = self.nested_list(InviteLinkTeam, self.value[:teams])

      def spent? = self.max_uses.to_i.positive? && self.uses.to_i >= self.max_uses.to_i

      def delete = self.discard(@resource)
    end

    class PublicInviteLink < Representation
      def name = self.value[:name]

      def skip_email_confirm = self.value[:skip_email_confirm]

      def teams = self.nested_list(InviteLinkTeam, self.value[:teams])
    end

    class UserInviteLinkPage < Page
      MEMBER = UserInviteLink
    end

    class InviteLinkTeamPage < Page
      MEMBER = InviteLinkTeam

      def member_resource(record) = @resource
    end

    module InviteLinks
      def invite_links(**parameters) = Collection.for(self, "admin/invite-links", UserInviteLinkPage, **parameters)

      def create_invite_link(payload) = self.submit(UserInviteLink, self.with(path: "admin/invite-links"), payload, identify: true)

      def remove_invite_link(id) = self.discard(self.with(path: "admin/invite-links/" + Vikunja.escape(id)))

      def invite_link_teams(**parameters) = Collection.for(self, "admin/teams", InviteLinkTeamPage, **parameters)

      def check_invite_link(token) = self.submit(PublicInviteLink, self.with(path: "invite-links/check"), {token: token})
    end
  end
end
