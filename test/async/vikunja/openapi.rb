# frozen_string_literal: true

require "async/vikunja/openapi"

describe Async::Vikunja::OpenAPI do
  let(:openapi) {subject}

  let(:pinned) {::File.read(::File.expand_path("../../../docker-compose.yml", __dir__))[%r{image: vikunja/vikunja:(\S+)}, 1]}

  it "reads the vendored v2 document" do
    expect(openapi.version).to be(:start_with?, "v2.")
    expect(openapi.prefix).to be == "/api/v2"
    expect(openapi.routes).not.to be(:empty?)
  end

  it "describes the release the tests are run against" do
    expect(openapi.version.delete_prefix("v")).to be == pinned
  end

  with "#route_for" do
    it "matches a literal path" do
      expect(openapi.route_for("GET", "/api/v2/projects")).to be == "/projects"
    end

    it "matches a templated path" do
      expect(openapi.route_for("GET", "/api/v2/projects/1/tasks")).to be == "/projects/{project}/tasks"
    end

    it "ignores the query" do
      expect(openapi.route_for("GET", "/api/v2/projects?page=2")).to be == "/projects"
    end

    it "rejects an undocumented path" do
      expect(openapi.route_for("GET", "/api/v2/nope")).to be_nil
    end

    it "rejects a method the path does not document" do
      expect(openapi.route_for("DELETE", "/api/v2/info")).to be_nil
    end

    it "rejects a path missing the server prefix" do
      expect(openapi.route_for("GET", "/projects")).to be_nil
    end
  end

  with "#security_for" do
    it "reports an unauthenticated operation" do
      expect(openapi.security_for("GET", "/api/v2/info")).to be == []
    end

    it "falls back to the document security" do
      expect(openapi.security_for("GET", "/api/v2/projects")).to be == [
        {"JWTKeyAuth" => []},
        {"APITokenAuth" => []},
      ]
    end
  end
end
