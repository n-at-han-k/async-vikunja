# async-vikunja

```ruby
gem "async-vikunja"
```

```ruby
require "async/vikunja"

Async::Vikunja::Client.open("https://vikunja.example.com/api/v2/") do |client|
  vikunja = client.authenticated(ENV.fetch("VIKUNJA_TOKEN"))

  vikunja.info.version
  vikunja.user.username
  vikunja.test_token.message
end
```

```ruby
Async::Vikunja::Client.open do |client|
  vikunja = client.authenticated(ENV.fetch("VIKUNJA_TOKEN"))
end
```

```ruby
jwt = Async::Vikunja::Client.open(url) do |client|
  client.login({username: "tester", password: "secret", long_token: true}).token
end
```

```ruby
vikunja.projects.map(&:title)
vikunja.projects(q: "inbox").first.id
vikunja.projects(is_archived: true).count

vikunja.projects.each_page(per_page: 25) do |page|
  page.page
  page.total
  page.total_pages
  page.items.size
  page.metadata["content-type"]

  page.each{|project| project.title}
end

vikunja.projects.take(2).map(&:title)
```

```ruby
project = vikunja.create_project({title: "Inbox", hex_color: "4287f5"})

project.id
project.identifier
project.owner.username
project.views.map(&:title)

vikunja.project(project.id).title
vikunja.project(project.id).update({id: project.id, title: "Renamed"})
vikunja.project(project.id).patch({title: "Patched"})
vikunja.project(project.id).delete
```

```ruby
project = vikunja.project(1)

task = project.create_task({title: "write the client", priority: 3})

project.tasks(filter: "done = false", sort_by: ["due_date"]).map(&:title)
project.task_by_index(1).title

vikunja.task(task.id).title
vikunja.task(task.id).update({id: task.id, title: "write the client", done: true})
vikunja.task(task.id).patch({percent_done: 0.5})
vikunja.task(task.id).mark_read
vikunja.task(task.id).delete
```

```ruby
vikunja.tasks(filter: "due_date > now", expand: "subtasks").each do |task|
  task.title
  task.due_date
  task.project_id
  task.done?
  task.labels.map(&:title)
  task.assignees.map(&:username)
end
```

```ruby
task = vikunja.task(7)

comment = task.create_comment({comment: "shipped"})

comment.author.username
task.task_comments(order_by: "desc").map(&:comment)
task.comment(comment.id).update({id: comment.id, comment: "shipped twice"})
task.comment(comment.id).delete
```

```ruby
label = vikunja.create_label({title: "urgent", hex_color: "e8384f"})

vikunja.task(7).add_label(label.id)
vikunja.task(7).task_labels.map(&:title)
vikunja.task(7).replace_labels([{id: label.id}])
vikunja.task(7).remove_label(label.id)

vikunja.labels.map(&:title)
vikunja.label(label.id).patch({title: "later"})
vikunja.label(label.id).delete
```

```ruby
vikunja.task(7).add_assignee(2)
vikunja.task(7).task_assignees.map(&:username)
vikunja.task(7).replace_assignees([{id: 2}, {id: 3}])
vikunja.task(7).remove_assignee(2)
```

```ruby
vikunja.task(7).add_relation({other_task_id: 8, relation_kind: "subtask"})
vikunja.task(7).remove_relation("subtask", 8)
vikunja.task(7).duplicate.duplicated_task.title
vikunja.task(7).reposition({project_view_id: 4, position: 2.5})
```

```ruby
view = vikunja.project(1).view(4)

view.view_kind
view.tasks.map(&:title)
view.buckets.map(&:title)
view.buckets_with_tasks.items.flat_map{|bucket| bucket.tasks.map(&:title)}

bucket = view.create_bucket({title: "Doing", limit: 5})

view.move_task(bucket.id, {task_id: 7, project_view_id: view.id})
view.update_bucket(bucket.id, {id: bucket.id, title: "In progress"})
view.remove_bucket(bucket.id)
```

```ruby
entry = vikunja.create_time_entry({task_id: 7, start_time: Time.now.utc.iso8601, comment: "pairing"})

vikunja.time_entries(filter: "start_time > now/w").map(&:comment)
vikunja.task(7).task_time_entries.map(&:id)
vikunja.project(1).time_entries.sum{|each| each.id}
vikunja.stop_timer.end_time
vikunja.time_entry(entry.id).delete
```

```ruby
team = vikunja.create_team({name: "platform", is_public: false})

team.add_member({username: "tester"})
team.members.map(&:username)
team.toggle_admin("tester")
team.remove_member("tester")

vikunja.project(1).add_team({team_id: team.id, permission: 1})
vikunja.project(1).teams.map(&:name)
vikunja.project(1).remove_team(team.id)
```

```ruby
share = vikunja.project(1).create_share({permission: 0, name: "read only"})

vikunja.project(1).shares.map(&:hash)
vikunja.authenticate_share(share.hash, {password: "secret"}).token
vikunja.project(1).remove_share(share.id)

vikunja.project(1).add_user({username: "tester", permission: 1})
vikunja.project(1).users.map(&:username)
vikunja.project(1).search_users("test").map(&:username)
vikunja.project(1).remove_user("tester")
```

```ruby
result = vikunja.task(7).upload_attachments([
  {name: "files", filename: "notes.txt", content_type: "text/plain", body: File.read("notes.txt")},
])

result.success.map{|attachment| attachment.file.name}
result.errors.map(&:message)

vikunja.task(7).task_attachments.map{|attachment| attachment.file.size}
vikunja.task(7).download_attachment(3).bytes
vikunja.task(7).attachment(3).delete
```

```ruby
vikunja.project(1).upload_background({name: "background", filename: "wall.jpg", content_type: "image/jpeg", body: File.read("wall.jpg")})

background = vikunja.project(1).background

background.media_type
background.bytes

vikunja.project(1).remove_background
```

```ruby
filter = vikunja.create_filter({title: "overdue", filters: {filter: "due_date < now && done = false"}})

vikunja.filter(filter.id).filters.filter
vikunja.filter(filter.id).patch({title: "late"})
vikunja.filter(filter.id).delete
```

```ruby
vikunja.notifications.map(&:name)
vikunja.update_notification(3, {id: 3, read: true})
vikunja.mark_notifications_read.message
vikunja.clear_notifications

vikunja.subscribe("projects", 1).entity
vikunja.unsubscribe("projects", 1)

vikunja.add_reaction("tasks", 7, {value: "👍"})
vikunja.reactions("tasks", 7).value
vikunja.remove_reaction("tasks", 7, {value: "👍"})
```

```ruby
webhook = vikunja.project(1).create_webhook({target_url: "https://example.com/hook", events: ["task.created"]})

vikunja.webhook_events.value
vikunja.project(1).webhooks.map(&:target_url)
vikunja.project(1).update_webhook(webhook.id, {id: webhook.id, events: ["task.updated"]})
vikunja.project(1).remove_webhook(webhook.id)
```

```ruby
token = vikunja.create_token({
  title: "integration",
  expires_at: (Time.now.utc + 86400).iso8601,
  permissions: {projects: ["read_all", "create"]},
})

token.token
vikunja.tokens.map(&:title)
vikunja.delete_token(token.id)

vikunja.caldav_tokens.map(&:created)
vikunja.create_caldav_token.token
```

```ruby
vikunja.user.settings.timezone
vikunja.update_settings({name: "Tester", week_start: 1, timezone: "Europe/London"}).message
vikunja.upload_avatar({name: "avatar", filename: "me.png", content_type: "image/png", body: File.read("me.png")})
vikunja.avatar("tester", size: 64).bytes
vikunja.set_avatar_provider(avatar_provider: "initials")

vikunja.enroll_totp.url
vikunja.enable_totp(passcode: "123456")
vikunja.totp_qrcode.bytes
vikunja.disable_totp(password: "secret")

vikunja.sessions.map(&:device_info)
vikunja.delete_session("abc")
```

```ruby
vikunja.users("test").map(&:username)
vikunja.timezones.value
vikunja.health.status
vikunja.routes.value
vikunja.notifications_atom.bytes
```

```ruby
bot = vikunja.create_bot({username: "ci-bot", name: "CI"})

vikunja.bots.map(&:username)
vikunja.bot(bot.id).patch({name: "CI runner"})
vikunja.bot(bot.id).delete
```

```ruby
overview = vikunja.admin_overview

overview.users
overview.projects
overview.shares.link_shares
overview.license.licensed

vikunja.admin_users(q: "test").map(&:username)
vikunja.create_admin_user({username: "new", email: "new@example.com", password: "secret"})
vikunja.set_admin(1, {is_admin: true})
vikunja.set_user_status(1, {status: 0})
vikunja.set_user_password(1, {new_password: "another"})
vikunja.send_password_reset_email(1)
vikunja.remove_admin_user(1, mode: "soft")

vikunja.admin_projects(q: "inbox").map(&:title)
vikunja.set_project_owner(1, {owner_id: 2})
```

```ruby
case vikunja.project(1)
in {title: String => title, owner: {username: String => owner}}
  [title, owner]
end

case vikunja.task(7)
in {done: true, title:}
  "#{title} is done"
in {done: false, due_date: String => due}
  "#{title} is due #{due}"
end
```

```ruby
begin
  vikunja.create_project({})
rescue Async::Vikunja::Failure => error
  error.status
  error.code
  error.title
  error.detail
  error.errors.map{|each| each[:message]}
  error.retry_after
end

begin
  vikunja.project(404).title
rescue Async::REST::ResponseError => error
  error.response.status
rescue ::JSON::ParserError => error
  error.message
end
```

```ruby
project = vikunja.project(1)

project.title
project = vikunja.project(1) unless project.cacheable?
project.title
```

```ruby
token = vikunja.create_token({title: "ci"})

token.inspect
token.value[:token]
```

```ruby
Async::Vikunja::Client.open(url) do |client|
  vikunja = client.authenticated(ENV.fetch("VIKUNJA_TOKEN"))

  tasks = vikunja.projects.map do |project|
    Async do
      project.tasks.count
    end
  end

  tasks.sum(&:wait)
end
```
