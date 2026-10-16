# frozen_string_literal: true

require "sus/fixtures/async/reactor_context"
require "async/http/internet"
require "json"

require "async/vikunja/openapi"
require "async/vikunja/environment"

describe "the live vikunja instance" do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) {Async::Vikunja::Environment["VIKUNJA_URL"]}

  let(:internet) do
    unless url
      skip "set VIKUNJA_URL: eval \"$(bin/vikunja-bootstrap)\""
    end

    Async::HTTP::Internet.new
  end

  def info
    response = internet.get(URI.join(url, "info").to_s, {"accept" => "application/json"})

    ::JSON.parse(response.read)
  ensure
    response&.close
  end

  after do
    @internet&.close
  end

  it "serves the api version the vendored document describes" do
    expect(info["version"]).to be == Async::Vikunja::OpenAPI.version
  end

  it "reports sqlite, so batched writes must be serialized" do
    expect(info["concurrent_writes"]).to be == false
  end
end
