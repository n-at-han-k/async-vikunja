require "async/vikunja"

describe Async::Vikunja::Wrapper do
  let(:wrapper) {subject.new}

  def response_for(content_type)
    ::Protocol::HTTP::Response[200, {"content-type" => content_type}, []]
  end

  with "#parser_for" do
    it "parses what the response declares as JSON" do
      expect(wrapper.parser_for(self.response_for("application/json"))).to be == Async::REST::Wrapper::JSON::Parser
    end

    it "parses a problem document, which the API answers errors with" do
      expect(wrapper.parser_for(self.response_for("application/problem+json"))).to be == Async::REST::Wrapper::JSON::Parser
    end

    it "leaves a translated response as the bytes that arrived" do
      expect(wrapper.parser_for(self.response_for("text/html"))).to be_nil
    end

    it "leaves a download as the bytes that arrived" do
      expect(wrapper.parser_for(self.response_for("application/octet-stream"))).to be_nil
    end

    it "leaves a response declaring nothing alone" do
      expect(wrapper.parser_for(::Protocol::HTTP::Response[204, {}, nil])).to be_nil
    end
  end

  with "#response_for" do
    it "performs exactly one request" do
      calls = 0

      resource = ::Protocol::HTTP::Middleware.for do |request|
        calls += 1

        ::Protocol::HTTP::Response[429, {"retry-after" => "0.01"}, []]
      end

      response = wrapper.response_for(resource, ::Protocol::HTTP::Request["GET", "/api/v2/projects"])

      expect(response.status).to be == 429
      expect(calls).to be == 1
    end
  end
end

describe Async::Vikunja::MergePatch do
  let(:wrapper) {subject.new}

  it "sends a merge patch and accepts JSON" do
    request = ::Protocol::HTTP::Request["PATCH", "/api/v2/projects/1"]

    wrapper.prepare_request(request, {title: "Inbox"})

    expect(request.headers["content-type"]).to be == "application/merge-patch+json"
    expect(request.headers["accept"]).to be == ["application/json"]
    expect(request.body.join).to be == ::JSON.dump({title: "Inbox"})
  end
end

describe Async::Vikunja::Multipart do
  let(:wrapper) {subject.new}

  it "sends each part under the field name the document gives it" do
    request = ::Protocol::HTTP::Request["POST", "/api/v2/tasks/1/attachments"]

    wrapper.prepare_request(request, [{name: "files", filename: "note.txt", content_type: "text/plain", body: "hello"}])

    expect(request.headers["content-type"]).to be(:start_with?, "multipart/form-data; boundary=")

    body = request.body.join

    expect(body).to be(:include?, "content-disposition: form-data; name=\"files\"; filename=\"note.txt\"")
    expect(body).to be(:include?, "content-type: text/plain")
    expect(body).to be(:include?, "hello")
  end
end

describe Async::Vikunja::Failure do
  def response_for(status, body, headers = {})
    case body
    when Hash
      chunk = ::JSON.dump(body)
    else
      chunk = body
    end

    ::Protocol::HTTP::Response[status, {"content-type" => "application/json"}.merge(headers), [chunk]]
  end

  it "reads the meaning of the failure from the problem document" do
    response = self.response_for(400, {status: 400, code: 4001, title: "Bad Request", detail: "nope"})
    response.body = Async::REST::Wrapper::JSON::Parser.new(response.body)

    failure = subject.for(response)

    expect(failure.status).to be == 400
    expect(failure.code).to be == 4001
    expect(failure.title).to be == "Bad Request"
    expect(failure.detail).to be == "nope"
    expect(failure.message).to be == "400: Bad Request"
  end

  it "keeps a body it could not read as the detail" do
    failure = subject.for(self.response_for(502, "<html>502</html>"))

    expect(failure.status).to be == 502
    expect(failure.detail).to be == "<html>502</html>"
  end

  it "keeps what the response said to wait" do
    response = self.response_for(429, {title: "Too Many Requests"}, {"retry-after" => "12"})
    response.body = Async::REST::Wrapper::JSON::Parser.new(response.body)

    expect(subject.for(response).retry_after).to be == "12"
  end
end

describe Async::Vikunja::Redacted do
  it "masks every key that names a credential" do
    redacted = subject.redact({token: "t", nested: {password: "p", name: "keep"}, list: [{secret: "s"}]})

    expect(redacted).to be == {
      token: "[redacted]",
      nested: {password: "[redacted]", name: "keep"},
      list: [{secret: "[redacted]"}],
    }
  end
end
