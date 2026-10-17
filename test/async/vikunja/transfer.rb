require "async/vikunja"
require "async/vikunja/server_context"

describe Async::Vikunja::Download do
  include_context Async::Vikunja::ServerContext

  let(:png) {"\x89PNG\r\n\x1A\n\x00\xFF\xD8".b}

  let(:attachment) {{id: 5, task_id: 1, file: {id: 9, name: "note.txt", mime: "text/plain", size: 5}}}

  def serve(path, body, content_type)
    respond("GET", path, body: body, headers: {"content-type" => content_type})
  end

  with "a file the API answers with" do
    it "reads the bytes that arrived, rather than a document" do
      self.serve("/api/v2/tasks/1/attachments/5", "the bytes of a file", "text/plain; charset=utf-8")

      expect(vikunja.task(1).download_attachment(5).bytes).to be == "the bytes of a file"
    end

    it "keeps binary bytes as they arrived" do
      self.serve("/api/v2/tasks/1/attachments/5", png, "image/png")

      downloaded = vikunja.task(1).download_attachment(5).bytes

      expect(downloaded.b).to be == png
      expect(downloaded.bytesize).to be == png.bytesize
    end

    it "says what the bytes are without the bytes being read first" do
      self.serve("/api/v2/tasks/1/attachments/5", png, "image/png")

      expect(vikunja.task(1).download_attachment(5).media_type).to be == "image/png"
    end

    it "fetches once however many times it is read" do
      self.serve("/api/v2/tasks/1/attachments/5", png, "image/png")

      download = vikunja.task(1).download_attachment(5)

      download.media_type
      download.bytes
      download.media_type

      expect(requests.size).to be == 1
    end

    it "asks for the file at the identifier the document publishes" do
      self.serve("/api/v2/tasks/1/attachments/5", png, "image/png")

      vikunja.task(1).download_attachment(5).bytes

      expect(requests.last[:route]).to be == "/tasks/{task}/attachments/{attachment}"
      expect(requests.last[:headers]["authorization"]).not.to be_nil
    end

    it "asks for a preview at one of the sizes the document names" do
      self.serve("/api/v2/tasks/1/attachments/5", png, "image/png")

      Async::Vikunja::TaskAttachment.new(vikunja.task(1).resource.with(path: "attachments/5")).preview("sm").bytes

      expect(requests.last[:query]).to be == {preview_size: "sm"}
      expect(requests.last[:route]).to be == "/tasks/{task}/attachments/{attachment}"
    end

    it "reports a refusal as the problem document the API answered with" do
      respond("GET", "/api/v2/tasks/1/attachments/5", status: 404, body: {status: 404, title: "Not Found"})

      failure = nil

      begin
        vikunja.task(1).download_attachment(5).bytes
      rescue Async::Vikunja::Failure => error
        failure = error
      end

      expect(failure.status).to be == 404
      expect(failure.title).to be == "Not Found"
    end

    it "refuses before a block is given anything to stream" do
      respond("GET", "/api/v2/tasks/1/attachments/5", status: 404, body: {status: 404, title: "Not Found"})

      streamed = false

      expect do
        vikunja.task(1).download_attachment(5) do |response|
          streamed = true
        end
      end.to raise_exception(Async::Vikunja::Failure)

      expect(streamed).to be == false
    end
  end

  with "a file too large to hold" do
    let(:large) {"x" * 200_000}

    it "hands the body to a block a chunk at a time" do
      self.serve("/api/v2/tasks/1/attachments/5", large, "application/octet-stream")

      chunks = []

      vikunja.task(1).download_attachment(5) do |response|
        response.body.each{|chunk| chunks << chunk.bytesize}
      end

      expect(chunks.size).to be > 1
      expect(chunks.sum).to be == 200_000
    end

    it "gives the block the headers alongside the bytes" do
      self.serve("/api/v2/tasks/1/attachments/5", large, "application/octet-stream")

      media_type = nil

      vikunja.task(1).download_attachment(5) do |response|
        media_type = response.headers["content-type"]
        response.body.each{|chunk| chunk}
      end

      expect(media_type).to be == "application/octet-stream"
    end

    it "answers with whatever the block returns" do
      self.serve("/api/v2/tasks/1/attachments/5", large, "application/octet-stream")

      counted = vikunja.task(1).download_attachment(5) do |response|
        total = 0

        response.body.each{|chunk| total += chunk.bytesize}

        total
      end

      expect(counted).to be == 200_000
    end

    it "streams an attachment that arrived inside a task" do
      respond("GET", "/api/v2/tasks/1", body: {id: 1, attachments: [{id: 5, task_id: 1, file: {id: 9}}]})
      self.serve("/api/v2/tasks/1/attachments/5", large, "application/octet-stream")

      chunks = 0

      vikunja.task(1).attachments.first.download do |response|
        response.body.each{chunks += 1}
      end

      expect(chunks).to be > 1
      expect(requests.last[:path]).to be == "/api/v2/tasks/1/attachments/5"
    end
  end

  with "the other files the client offers" do
    it "downloads an avatar" do
      self.serve("/api/v2/avatar/tester", png, "image/png")

      expect(vikunja.avatar("tester", size: 48).bytes.b).to be == png
      expect(requests.last[:route]).to be == "/avatar/{username}"
    end

    it "downloads a project background" do
      self.serve("/api/v2/projects/1/background", png, "image/jpeg")

      expect(vikunja.project(1).background.bytes.b).to be == png
    end

    it "downloads an export, which is asked for with a password" do
      respond("POST", "/api/v2/user/export/download", body: png, headers: {"content-type" => "application/zip"})

      expect(vikunja.download_export(password: "hunter2").bytes.b).to be == png
      expect(requests.last[:payload]).to be == ::JSON.dump({password: "hunter2"})
    end

    it "streams an export, which is asked for the same way" do
      respond("POST", "/api/v2/user/export/download", body: "x" * 200_000,
        headers: {"content-type" => "application/zip"})

      chunks = []

      vikunja.download_export(password: "hunter2") do |response|
        response.body.each{|chunk| chunks << chunk.bytesize}
      end

      expect(chunks.size).to be > 1
      expect(chunks.sum).to be == 200_000
      expect(requests.last[:payload]).to be == ::JSON.dump({password: "hunter2"})
    end

    it "asks for whatever the API will answer a file with" do
      self.serve("/api/v2/avatar/tester", png, "image/png")

      vikunja.avatar("tester").bytes

      expect(requests.last[:headers]["accept"]).to be == ["*/*"]
    end
  end
end

describe Async::Vikunja::AttachmentUploadResult do
  include_context Async::Vikunja::ServerContext

  let(:png) {"\x89PNG\r\n\x1A\n\x00\xFF\xD8".b}

  let(:attachment) {{id: 5, task_id: 1, file: {id: 9, name: "dot.png", mime: "image/png", size: 11}}}

  def upload(parts)
    respond("POST", "/api/v2/tasks/1/attachments", status: 201, body: {success: [attachment], errors: nil})

    vikunja.task(1).upload_attachments(parts)
  end

  it "sends the part under the field name the document requires" do
    self.upload([{name: "files", filename: "dot.png", content_type: "image/png", body: png}])

    expect(requests.last[:route]).to be == "/tasks/{task}/attachments"
    expect(requests.last[:headers]["content-type"]).to be(:start_with?, "multipart/form-data; boundary=")
    expect(requests.last[:payload]).to be(:include?, "name=\"files\"; filename=\"dot.png\"")
  end

  it "puts binary bytes on the wire unchanged" do
    self.upload([{name: "files", filename: "dot.png", content_type: "image/png", body: png}])

    expect(requests.last[:payload].b).to be(:include?, png)
  end

  it "sends every part it is given" do
    self.upload([
      {name: "files", filename: "dot.png", content_type: "image/png", body: png},
      {name: "files", filename: "café.txt", content_type: "text/plain", body: "café"},
    ])

    payload = requests.last[:payload].b

    expect(payload).to be(:include?, png)
    expect(payload).to be(:include?, "café".b)
  end

  it "reads what the API says it stored" do
    result = self.upload([{name: "files", filename: "dot.png", content_type: "image/png", body: png}])

    stored = result.success.first

    expect(stored.id).to be == 5
    expect(stored.file.name).to be == "dot.png"
    expect(stored.file.size).to be == 11
    expect(result.errors).to be == []
  end

  it "identifies what it stored at the identifier the document publishes" do
    stored = self.upload([{name: "files", filename: "dot.png", content_type: "image/png", body: png}]).success.first

    expect(stored.resource.reference.path.to_s).to be == "/api/v2/tasks/1/attachments/5"
  end

  it "reads the refusals the API reports beside what it stored" do
    respond("POST", "/api/v2/tasks/1/attachments", status: 201,
      body: {success: [], errors: [{code: 4016, message: "file is too large"}]})

    result = vikunja.task(1).upload_attachments([{name: "files", filename: "big.bin", body: "x"}])

    expect(result.success).to be == []
    expect(result.errors.first.code).to be == 4016
    expect(result.errors.first.message).to be == "file is too large"
  end
end

describe Async::Vikunja::TaskAttachment do
  include_context Async::Vikunja::ServerContext

  let(:attachment) {{id: 5, task_id: 1, file: {id: 9, name: "note.txt", mime: "text/plain", size: 5}}}

  let(:task) {{id: 1, title: "write the client", attachments: [attachment]}}

  let(:listed) {vikunja.task(1).attachments.first}

  before do
    respond("GET", "/api/v2/tasks/1", body: task)
  end

  it "knows its own address when it arrived inside a task" do
    expect(listed.resource.reference.path.to_s).to be == "/api/v2/tasks/1/attachments/5"
  end

  it "downloads itself rather than the task it arrived in" do
    respond("GET", "/api/v2/tasks/1/attachments/5", body: "the bytes of a file",
      headers: {"content-type" => "text/plain"})

    expect(listed.download.bytes).to be == "the bytes of a file"
    expect(requests.last[:route]).to be == "/tasks/{task}/attachments/{attachment}"
  end

  it "deletes itself rather than the task it arrived in" do
    respond("DELETE", "/api/v2/tasks/1/attachments/5", status: 204)

    expect(listed.delete).to be == true
    expect(requests.last[:method]).to be == "DELETE"
    expect(requests.last[:path]).to be == "/api/v2/tasks/1/attachments/5"
  end

  it "reads the file the task says is attached" do
    expect(listed.file.name).to be == "note.txt"
    expect(listed.file.mime).to be == "text/plain"
  end
end
