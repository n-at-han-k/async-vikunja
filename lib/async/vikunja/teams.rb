require_relative "page"

module Async
  module Vikunja
    class Team < Representation
      def id = self.value[:id]

      def name = self.value[:name]

      def description = self.value[:description]

      def is_public = self.value[:is_public]

      def external_id = self.value[:external_id]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def created_by = self.nested(User, self.value[:created_by])

      def members = self.nested_list(TeamUser, self.value[:members])

      def max_permission = self.value[:max_permission]

      def public? = self.is_public == true

      def add_member(payload) = self.submit(TeamMember, @resource.with(path: "members"), payload)

      def remove_member(user) = self.discard(@resource.with(path: "members/" + Vikunja.escape(user)))

      def toggle_admin(user) = self.submit(TeamMember, @resource.with(path: "members/" + Vikunja.escape(user) + "/admin"), nil)

      def update(payload) = self.submit(Team, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(Team, @resource, payload)

      def delete = self.discard(@resource)
    end

    class TeamMember < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def admin = self.value[:admin]

      def created = self.value[:created]

      def admin? = self.admin == true
    end

    class TeamUser < Representation
      def id = self.value[:id]

      def username = self.value[:username]

      def name = self.value[:name]

      def email = self.value[:email]

      def admin = self.value[:admin]

      def bot_owner_id = self.value[:bot_owner_id]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def admin? = self.admin == true
    end

    class TeamPage < Page
      MEMBER = Team
    end

    module Teams
      def teams(**parameters) = Collection.for(self, "teams", TeamPage, **parameters)

      def team(id) = Team.new(self.with(path: "teams/" + Vikunja.escape(id)))

      def create_team(payload) = self.submit(Team, self.with(path: "teams"), payload, identify: true)
    end
  end
end
