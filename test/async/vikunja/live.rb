require "async/vikunja/live_context"

describe Async::Vikunja::Client do
  include_context Async::Vikunja::LiveContext

  with "the instance itself" do
    it "reports the version the vendored document describes" do
      expect(vikunja.info.version).to be == Async::Vikunja::OpenAPI.version
    end

    it "accepts the token the bootstrap issued" do
      expect(vikunja.test_token.message).to be == "ok"
    end

    it "names the user the token belongs to" do
      expect(vikunja.user.username).not.to be_nil
    end
  end

  with "a project" do
    it "creates, reads, updates and deletes one" do
      title = self.unique("project")

      created = vikunja.create_project({title: title})

      expect(created.id).to be_a(Integer)
      expect(created.title).to be == title

      read = vikunja.project(created.id)

      expect(read.title).to be == title
      expect(read.owner.username).not.to be_nil

      renamed = read.update({title: title + "-renamed", id: created.id})

      expect(renamed.title).to be == title + "-renamed"

      patched = vikunja.project(created.id).patch({title: title + "-patched"})

      expect(patched.title).to be == title + "-patched"

      expect(vikunja.project(created.id).delete).to be == true

      status = nil

      begin
        vikunja.project(created.id).title
      rescue Async::REST::ResponseError => error
        status = error.response.status
      end

      expect(status).to be == 404
    end

    it "lists one page at a time, and every project across them" do
      titles = [self.unique("page-a"), self.unique("page-b"), self.unique("page-c")]

      created = titles.map{|title| vikunja.create_project({title: title})}

      begin
        pages = vikunja.projects.each_page(per_page: 2).to_a

        expect(pages.size).to be >= 2

        pages.each do |page|
          expect(page.items.size).to be <= 2
          expect(page.metadata["content-type"]).not.to be_nil
        end

        listed = vikunja.projects.map(&:title)

        titles.each do |title|
          expect(listed).to be(:include?, title)
        end
      ensure
        created.each{|project| vikunja.project(project.id).delete}
      end
    end

    it "identifies a listed project at its own address" do
      title = self.unique("member")
      created = vikunja.create_project({title: title})

      begin
        member = vikunja.projects(q: title).first

        expect(member.title).to be == title
        expect(member.resource.reference.to_s).to be(:end_with?, "/projects/" + created.id.to_s)
        expect(Async::Vikunja::Project.new(member.resource).title).to be == title
      ensure
        vikunja.project(created.id).delete
      end
    end
  end

  with "a task" do
    it "creates one in a project and reads it back on its own" do
      project = vikunja.create_project({title: self.unique("tasks")})

      begin
        created = project.create_task({title: "write the client"})

        expect(created.id).to be_a(Integer)

        task = vikunja.task(created.id)

        expect(task.title).to be == "write the client"
        expect(task.project_id).to be == project.id

        listed = project.tasks.map(&:id)

        expect(listed).to be(:include?, created.id)

        done = task.update({id: created.id, title: "write the client", done: true, project_id: project.id})

        expect(done.done).to be == true

        comment = vikunja.task(created.id).create_comment({comment: "shipped"})

        expect(comment.comment).to be == "shipped"
        expect(comment.author.username).not.to be_nil

        comments = vikunja.task(created.id).task_comments.map(&:comment)

        expect(comments).to be(:include?, "shipped")
      ensure
        vikunja.project(project.id).delete
      end
    end
  end

  with "a label" do
    it "creates one and attaches it to a task" do
      project = vikunja.create_project({title: self.unique("labels")})

      begin
        label = vikunja.create_label({title: self.unique("label")})
        task = project.create_task({title: "labelled"})

        attached = vikunja.task(task.id).add_label(label.id)

        expect(attached.label_id).to be == label.id

        titles = vikunja.task(task.id).task_labels.map(&:title)

        expect(titles).to be(:include?, label.title)

        expect(vikunja.task(task.id).remove_label(label.id)).to be == true
        expect(vikunja.label(label.id).delete).to be == true
      ensure
        vikunja.project(project.id).delete
      end
    end
  end

  with "a failure the instance reports" do
    it "carries the problem document the API answers with" do
      failure = nil

      begin
        vikunja.create_project({})
      rescue Async::Vikunja::Failure => error
        failure = error
      end

      expect(failure).not.to be_nil
      expect(failure.status).to be >= 400
      expect(failure.title).not.to be_nil
    end
  end
end
