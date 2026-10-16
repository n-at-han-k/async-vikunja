require "async/vikunja"
require "async/vikunja/server_context"

describe Async::Vikunja::Client do
  include_context Async::Vikunja::ServerContext

  let(:project) {{id: 1, title: "Inbox", identifier: "INB", owner: {id: 2, username: "tester"}}}

  def envelope(items, total_pages: 1, page: 1)
    {items: items, page: page, per_page: items.size, total: items.size, total_pages: total_pages}
  end

  with "a project" do
    it "reads the identified resource and accepts JSON" do
      respond("GET", "/api/v2/projects/1", body: project)

      expect(vikunja.project(1).title).to be == "Inbox"

      expect(requests.last).to have_keys(
        method: be == "GET",
        route: be == "/projects/{id}",
        path: be == "/api/v2/projects/1",
      )

      expect(requests.last[:headers]["accept"]).to be == ["application/json"]
    end

    it "reads a nested object out of the response it arrived in" do
      respond("GET", "/api/v2/projects/1", body: project)

      owner = vikunja.project(1).owner

      expect(owner).to be_a(Async::Vikunja::User)
      expect(owner.username).to be == "tester"
      expect(requests.size).to be == 1
    end

    it "discriminates the kind of representation that arrived" do
      respond("GET", "/api/v2/projects/1", body: project)

      matched = nil

      case vikunja.project(1)
      in {title: String => title}
        matched = title
      end

      expect(matched).to be == "Inbox"
    end

    it "creates one from the payload it is given" do
      respond("POST", "/api/v2/projects", status: 201, body: project)

      created = vikunja.create_project({title: "Inbox"})

      expect(created.id).to be == 1
      expect(requests.last[:method]).to be == "POST"
      expect(requests.last[:payload]).to be == ::JSON.dump({title: "Inbox"})
    end

    it "reports what a failed write meant" do
      respond("POST", "/api/v2/projects", status: 412,
        body: {status: 412, code: 3001, title: "Precondition Failed", detail: "title cannot be empty"})

      failure = nil

      begin
        vikunja.create_project({})
      rescue Async::Vikunja::Failure => error
        failure = error
      end

      expect(failure.status).to be == 412
      expect(failure.code).to be == 3001
      expect(failure.title).to be == "Precondition Failed"
      expect(failure.detail).to be == "title cannot be empty"
    end

    it "reports what a failed read meant" do
      respond("GET", "/api/v2/projects/1", status: 404, body: {status: 404, title: "Not Found"})

      status = nil

      begin
        vikunja.project(1).title
      rescue Async::REST::ResponseError => error
        status = error.response.status
      end

      expect(status).to be == 404
    end
  end

  with "a listing" do
    it "yields a member for every record it already received" do
      respond("GET", "/api/v2/projects", body: envelope([project, project.merge(id: 2, title: "Work")]))

      titles = vikunja.projects.map(&:title)

      expect(titles).to be == ["Inbox", "Work"]
      expect(requests.size).to be == 1
    end

    it "identifies each member independently of the collection" do
      respond("GET", "/api/v2/projects", body: envelope([project]))

      member = vikunja.projects(q: "in").first

      expect(member.resource.reference.to_s).to be == "/api/v2/projects/1"
    end

    it "asks for the page it is given" do
      respond("GET", "/api/v2/projects", body: envelope([project]))

      vikunja.projects.each_page(per_page: 25).to_a

      expect(requests.last[:query]).to have_keys(page: be == "1", per_page: be == "25")
    end

    it "stops when the document says there are no more pages" do
      respond("GET", "/api/v2/projects", body: envelope([project]))

      vikunja.projects.to_a

      expect(requests.size).to be == 1
    end
  end

  with "a response that means wait" do
    it "performs one request per read, whatever the response says" do
      respond("GET", "/api/v2/projects/1", status: 429, body: {title: "Too Many Requests"},
        headers: {"retry-after" => "0.01"})

      begin
        vikunja.project(1).title
      rescue Async::REST::ResponseError
        nil
      end

      expect(requests.size).to be == 1
    end

    it "builds each retried write from the same identifier" do
      respond("POST", "/api/v2/projects", status: 429, body: {title: "Too Many Requests"},
        headers: {"retry-after" => "0.01"})

      begin
        vikunja.create_project({title: "Inbox"})
      rescue Async::Vikunja::Failure
        nil
      end

      expect(requests.size).to be == Async::Vikunja::Submit::MAXIMUM_ATTEMPTS

      expect(requests.map{|request| [request[:path], request[:query]]}.uniq.size).to be == 1
    end
  end

  with "a representation holding a credential" do
    it "masks the credential when it is inspected" do
      token = Async::Vikunja::APIToken.new(vikunja, value: {id: 1, title: "ci", token: "tk_secret"})

      expect(token.inspect).to be(:include?, "[redacted]")
      expect(token.inspect).not.to be(:include?, "tk_secret")
      expect(token.value[:token]).to be == "tk_secret"
    end
  end
end
