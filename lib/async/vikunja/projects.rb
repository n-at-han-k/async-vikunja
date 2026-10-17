require_relative "page"

module Async
  module Vikunja
    class Project < Representation
      def id = self.value[:id]

      def title = self.value[:title]

      def description = self.value[:description]

      def identifier = self.value[:identifier]

      def hex_color = self.value[:hex_color]

      def position = self.value[:position]

      def parent_project_id = self.value[:parent_project_id]

      def is_archived = self.value[:is_archived]

      def is_favorite = self.value[:is_favorite]

      def max_permission = self.value[:max_permission]

      def background_blur_hash = self.value[:background_blur_hash]

      def background_information = self.value[:background_information]

      def created = self.value[:created]

      def updated = self.value[:updated]

      def owner = self.nested(User, self.value[:owner])

      def subscription = self.nested(Subscription, self.value[:subscription])

      def views = self.nested_list(ProjectView, self.value[:views])

      def archived? = self.is_archived == true

      def favorite? = self.is_favorite == true

      def tasks(**parameters) = Collection.for(@resource, "tasks", ProjectTaskPage, **parameters)

      def project_views(**parameters) = Collection.for(@resource, "views", ProjectViewPage, **parameters)

      def shares(**parameters) = Collection.for(@resource, "shares", LinkSharingPage, **parameters)

      def teams(**parameters) = Collection.for(@resource, "teams", TeamWithPermissionPage, **parameters)

      def users(**parameters) = Collection.for(@resource, "users", ProjectUserPage, **parameters)

      def webhooks(**parameters) = Collection.for(@resource, "webhooks", ProjectWebhookPage, **parameters)

      def time_entries(**parameters) = Collection.for(@resource, "time-entries", ProjectTimeEntryPage, **parameters)

      def view(id) = ProjectView.new(@resource.with(path: "views/" + Vikunja.escape(id)))

      def share(id) = LinkSharing.new(@resource.with(path: "shares/" + Vikunja.escape(id)))

      def task_by_index(index) = TaskReadOneBody.new(@resource.with(path: "tasks/by-index/" + Vikunja.escape(index)))

      def background(&block) = Download.open(@resource.with(path: "background"), &block)

      def search_users(query) = UserSearchPage.new(@resource.with(path: "users/search", parameters: {q: query}))

      def create_task(payload) = self.submit(Task, @resource.with(path: "tasks"), payload, identify: "../../../tasks/")

      def create_tasks(titles) = self.submit(BulkTaskCreation, @resource.with(path: "tasks/bulk"), {tasks: titles}, identify: nil)

      def create_view(payload) = self.submit(ProjectView, @resource.with(path: "views"), payload, identify: true)

      def create_share(payload) = self.submit(LinkSharing, @resource.with(path: "shares"), payload, identify: true)

      def create_webhook(payload) = self.submit(Webhook, @resource.with(path: "webhooks"), payload, identify: true)

      def add_team(payload) = self.submit(TeamProject, @resource.with(path: "teams"), payload)

      def add_user(payload) = self.submit(ProjectUser, @resource.with(path: "users"), payload)

      def update_team(team, payload) = self.submit(TeamProject, @resource.with(path: "teams/" + Vikunja.escape(team)), payload, method: :put)

      def update_user(user, payload) = self.submit(ProjectUser, @resource.with(path: "users/" + Vikunja.escape(user)), payload, method: :put)

      def update_webhook(webhook, payload) = self.submit(Webhook, @resource.with(path: "webhooks/" + Vikunja.escape(webhook)), payload, method: :put)

      def remove_team(team) = self.discard(@resource.with(path: "teams/" + Vikunja.escape(team)))

      def remove_user(user) = self.discard(@resource.with(path: "users/" + Vikunja.escape(user)))

      def remove_webhook(webhook) = self.discard(@resource.with(path: "webhooks/" + Vikunja.escape(webhook)))

      def remove_share(id) = self.discard(@resource.with(path: "shares/" + Vikunja.escape(id)))

      def duplicate(payload = {}) = self.submit(ProjectDuplicate, @resource.with(path: "duplicate"), payload)

      def upload_background(part) = self.upload(Project, @resource.with(path: "backgrounds/upload"), [part], method: :put)

      def remove_background = self.submit(Project, @resource.with(path: "background"), nil, method: :delete)

      def update(payload) = self.submit(Project, @resource, payload, method: :put)

      def patch(payload) = self.merge_patch(Project, @resource, payload)

      def delete = self.discard(@resource)
    end

    class ProjectDuplicate < Representation
      def parent_project_id = self.value[:parent_project_id]

      def duplicate_shares = self.value[:duplicate_shares]

      def duplicated_project = self.nested(Project, self.value[:duplicated_project])
    end

    class ProjectPage < Page
      MEMBER = Project
    end

    class AdminProjectPage < ProjectPage
      def member_path(record) = "../../projects/" + Vikunja.escape(record[:id])
    end

    module Projects
      def projects(**parameters) = Collection.for(self, "projects", ProjectPage, **parameters)

      def project(id) = Project.new(self.with(path: "projects/" + Vikunja.escape(id)))

      def create_project(payload) = self.submit(Project, self.with(path: "projects"), payload, identify: true)
    end
  end
end
