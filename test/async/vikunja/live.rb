require "tmpdir"

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

  with "an attachment" do
    let(:png) {"\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x02\x00\x00\x00\x02\b\x02\x00\x00\x00\xFD\xD4\x9As\x00\x00\x00\x10IDATx\x9Cc\xF8\xCF\xC0\x00D\f\x10\n\x00\x1F\xEE\x03\xFD\x8B_\x14\xD4\x00\x00\x00\x00IEND\xAEB`\x82".b}

    let(:text) {{name: "files", filename: "note.txt", content_type: "text/plain", body: "the bytes of a file"}}

    let(:image) {{name: "files", filename: "café.png", content_type: "image/png", body: png}}

    def stored_as(result, name) = result.success.find{|attachment| attachment.file.name == name}

    it "uploads several files at once and downloads each one byte for byte" do
      project = vikunja.create_project({title: self.unique("attachments")})

      begin
        task = vikunja.task(project.create_task({title: "attached"}).id)

        result = task.upload_attachments([text, image])

        expect(result.errors).to be == []
        expect(result.success.size).to be == 2

        stored_text = self.stored_as(result, "note.txt")
        stored_image = self.stored_as(result, "café.png")

        expect(stored_text.file.size).to be == 19
        expect(stored_image.file.mime).to be == "image/png"
        expect(stored_image.file.size).to be == png.bytesize

        expect(stored_text.download.bytes).to be == "the bytes of a file"
        expect(stored_text.download.media_type).to be(:start_with?, "text/plain")

        expect(stored_image.download.bytes.b).to be == png
        expect(stored_image.download.media_type).to be == "image/png"
      ensure
        vikunja.project(project.id).delete
      end
    end

    it "identifies an attachment at its own address, however it arrived" do
      project = vikunja.create_project({title: self.unique("attachment-address")})

      begin
        task = vikunja.task(project.create_task({title: "attached"}).id)
        stored = task.upload_attachments([text]).success.first

        listed = vikunja.task(task.id).task_attachments.first
        nested = vikunja.task(task.id).attachments.first

        address = "/attachments/" + stored.id.to_s

        [stored, listed, nested].each do |attachment|
          expect(attachment.id).to be == stored.id
          expect(attachment.resource.reference.path.to_s).to be(:end_with?, address)
          expect(attachment.download.bytes).to be == "the bytes of a file"
        end
      ensure
        vikunja.project(project.id).delete
      end
    end

    it "deletes an attachment without deleting the task it is on" do
      project = vikunja.create_project({title: self.unique("attachment-delete")})

      begin
        task = vikunja.task(project.create_task({title: "attached"}).id)
        task.upload_attachments([text])

        expect(vikunja.task(task.id).attachments.first.delete).to be == true

        expect(vikunja.task(task.id).title).to be == "attached"
        expect(vikunja.task(task.id).task_attachments.to_a).to be(:empty?)
      ensure
        vikunja.project(project.id).delete
      end
    end

    it "streams a large file up from disk and back down a chunk at a time" do
      project = vikunja.create_project({title: self.unique("streaming")})
      path = ::File.join(Dir.tmpdir, self.unique("async-vikunja") + ".bin")

      begin
        ::File.binwrite(path, "x" * 2_000_000)

        task = vikunja.task(project.create_task({title: "streamed"}).id)

        stored = task.upload_attachments([
          {name: "files", filename: "big.bin", content_type: "application/octet-stream",
           body: ::File.open(path, ::File::RDONLY | ::File::BINARY)},
        ]).success.first

        expect(stored.file.size).to be == 2_000_000

        chunks = []

        stored.download do |response|
          response.body.each{|chunk| chunks << chunk.bytesize}
        end

        expect(chunks.size).to be > 1
        expect(chunks.sum).to be == 2_000_000
      ensure
        ::File.unlink(path)
        vikunja.project(project.id).delete
      end
    end

    it "downloads a preview the server sized for it" do
      project = vikunja.create_project({title: self.unique("attachment-preview")})

      begin
        task = vikunja.task(project.create_task({title: "attached"}).id)
        stored = task.upload_attachments([image]).success.first

        preview = stored.preview("sm")

        expect(preview.bytes.bytesize).to be > 0
        expect(preview.media_type).to be(:start_with?, "image/")
      ensure
        vikunja.project(project.id).delete
      end
    end
  end

  with "a project background" do
    let(:png) {"\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x02\x00\x00\x00\x02\b\x02\x00\x00\x00\xFD\xD4\x9As\x00\x00\x00\x10IDATx\x9Cc\xF8\xCF\xC0\x00D\f\x10\n\x00\x1F\xEE\x03\xFD\x8B_\x14\xD4\x00\x00\x00\x00IEND\xAEB`\x82".b}

    it "uploads an image and downloads what the server made of it" do
      project = vikunja.create_project({title: self.unique("background")})

      begin
        updated = vikunja.project(project.id)
          .upload_background({name: "background", filename: "dot.png", content_type: "image/png", body: png})

        expect(updated.background_information).not.to be_nil

        background = vikunja.project(project.id).background

        expect(background.media_type).to be(:start_with?, "image/")
        expect(background.bytes.bytesize).to be > 0
      ensure
        vikunja.project(project.id).delete
      end
    end
  end

  with "an avatar" do
    it "downloads the one the instance serves for a user" do
      avatar = vikunja.avatar(vikunja.user.username, size: 48)

      expect(avatar.bytes.bytesize).to be > 0
      expect(avatar.media_type).not.to be_nil
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
