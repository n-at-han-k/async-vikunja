# Errors

Rules for error handling and retry. Each rule states what must be true, shows wrong and right
code with its usage, and gives the reason from Fielding's dissertation in
the HTTP specification.

The library raises in exactly three places:

```
representation.rb:91    raise ResponseError, response      # lazy #get, non-success status
wrapper/generic.rb:49   raise                              # re-raise after closing the response
wrapper/generic.rb:85   raise UnsupportedError, super      # inside Generic::Unsupported#join
```

`RequestError` is never raised by the library. `Generic::Unsupported` is never returned by a
built-in `parser_for`. Both exist for a client to use.

Numbering continues from `architecture.md`. Cite rule numbers when reviewing.

---

# 18. Response Error Rule

**Rescue `Async::REST::ResponseError` and read what the failure means from `error.response`.
Never decide from the exception message.**

```ruby
# WRONG - the decision is taken from a string built out of the body
class Client < Async::REST::Resource
	def task(id)
		Task.new(self.with(path: "tasks/#{id}"))
	end
end

Client.open("https://api.example.com/v1/") do |client|
	begin
		client.task(9).title
	rescue Async::REST::ResponseError => error
		return nil if error.message.include?("not_found")

		raise
	end
end
```

```ruby
# RIGHT - the decision is taken from the control data the response carried
class Client < Async::REST::Resource
	def task(id)
		Task.new(self.with(path: "tasks/#{id}"))
	end
end

Client.open("https://api.example.com/v1/") do |client|
	begin
		client.task(9).title
	rescue Async::REST::ResponseError => error
		case error.response.status
		when 404 then nil
		else raise
		end
	end
end
# => nil
```

**Reason:** §5.2.1.2 — "Control data defines the purpose of a message between components, such
as the action being requested or the meaning of a response." The status is that control data,
and `ResponseError` keeps it through `attr :response`. The message is a String assembled from
the body, so deciding from it decides from the representation rather than from the meaning of
the response.

---

# 19. Processing Failure Rule

**A body that cannot be parsed is not a response error. It does not descend from
`Async::REST::Error`, so rescue it separately.**

```ruby
# WRONG - a malformed body escapes this rescue
class Client < Async::REST::Resource
	def task(id)
		Task.new(self.with(path: "tasks/#{id}"))
	end
end

Client.open("https://api.example.com/v1/") do |client|
	begin
		client.task(1).title
	rescue Async::REST::Error => error
		$stderr.puts "request failed: #{error.message}"
	end
end
# JSON::ParserError is not an Async::REST::Error, so it escapes
```

```ruby
# RIGHT - the two failures are rescued as the separate things they are
class Client < Async::REST::Resource
	def task(id)
		Task.new(self.with(path: "tasks/#{id}"))
	end
end

Client.open("https://api.example.com/v1/") do |client|
	begin
		client.task(1).title
	rescue Async::REST::ResponseError => error
		$stderr.puts "the response means failure: #{error.response.status}"
	rescue ::JSON::ParserError => error
		$stderr.puts "the representation could not be processed: #{error.class}"
	end
end
# the representation could not be processed: JSON::ParserError
```

**Reason:** Table 5-1 lists `representation` and `control data` as separate data elements, and
§5.2.1.2 has a representation "processed by the recipient according to the control data of the
message and the nature of the media type". A body that will not parse is a failure of
representation processing; a 4xx is the response's meaning. Two data elements, two failures,
two rescues.

---

# 20. Independent Retry Rule

**Retry by building a new request. Never re-send a request object that has already been sent.**

```ruby
# WRONG - the same request object is sent again, and Resource#call has mutated it
class Wrapper < Async::REST::Wrapper::JSON
	def response_for(resource, request)
		while true
			response = resource.call(request)

			return response unless response.status == 429

			sleep(response.headers["retry-after"].to_f)
		end
	end
end

Client.open("https://api.example.com/v1/") do |client|
	client.with(parameters: {token: "secret"}).rooms
end
# the server sees:
#   /v1/rooms?token=secret
#   /v1/rooms?token=secret?token=secret
#   /v1/rooms?token=secret?token=secret?token=secret
```

```ruby
# RIGHT - each attempt builds its own request from the reference
class Client < Async::REST::Resource
	MAXIMUM_ATTEMPTS = 4
	MAXIMUM_DELAY = 30.0

	def rooms
		self.with_retry{Rooms.new(self.with(path: "rooms")).tap(&:value)}
	end

	private def with_retry(attempts: MAXIMUM_ATTEMPTS)
		attempt = 0

		while true
			attempt += 1

			begin
				return yield
			rescue Async::REST::ResponseError => error
				raise if attempt >= attempts
				raise unless error.response.status == 429

				delay = error.response.headers["retry-after"]&.to_f or raise
				raise if delay > MAXIMUM_DELAY

				sleep(delay)
			end
		end
	end
end

Client.open("https://api.example.com/v1/") do |client|
	client.with(parameters: {token: "secret"}).rooms.names
end
# => ["general"]
# the server sees:
#   /v1/rooms?token=secret
#   /v1/rooms?token=secret
#   /v1/rooms?token=secret
```

**Reason:** §5.2.2 — "each request contains all of the information necessary for a connector to
understand the request, independent of any requests that may have preceded it."
`Resource#call` assigns `request.path = @reference.with(path: request.path).to_s`, mutating the
request in place, so a re-sent request is a function of how many times it has already been sent
and is no longer independent.

---

# 21. Single Request Rule

**A wrapper performs exactly one request per call. Reading `retry-after` is the connector's
business; replaying a request is not.**

```ruby
# WRONG - the inherited response_for loops, so the wrapper replays requests
class Wrapper < Async::REST::Wrapper::JSON
end

class Rooms < Async::REST::Representation[Wrapper]
end

Client.open("https://api.example.com/v1/") do |client|
	Rooms.get(client.with(path: "rooms"))
end
```

```ruby
# RIGHT - one request per call; retry is the caller's, per rule 20
class Wrapper < Async::REST::Wrapper::JSON
	def response_for(resource, request)
		resource.call(request)
	end
end

class Rooms < Async::REST::Representation[Wrapper]
end

Client.open("https://api.example.com/v1/") do |client|
	Rooms.get(client.with(path: "rooms"))
end
```

**Reason:** §5.2.1.2 puts `retry-after` in its proper category — control data is "used to
parameterize requests and override the default behavior of some connecting elements", the
sentence's own example being cache behaviour. So a connector may read it. But §5.2.2 requires
each request to be independent, and at the connector layer the only thing available to replay
is the request already mutated by `Resource#call`, so a connector that retries cannot satisfy
both.

---

# 23. Single Application Rule

**Derive a path relatively. Never build one from a serialised reference, and never send a
request through a resource twice.**

```ruby
# WRONG - the path is built from a reference that already carries its parameters
class Client < Async::REST::Resource
	def rooms
		Rooms.new(self.with(path: "#{self.reference}/rooms"))
	end
end

Client.open("https://api.example.com/v1/") do |client|
	client.with(parameters: {token: "secret"}).rooms
end
# the resource is addressed as:
#   "/v1/?token=secret/rooms?token=secret"
```

```ruby
# RIGHT - the reference is applied once, by the resource
class Client < Async::REST::Resource
	def rooms
		Rooms.new(self.with(path: "rooms"))
	end
end

Client.open("https://api.example.com/v1/") do |client|
	client.with(parameters: {token: "secret"}).rooms
end
# the resource is addressed as:
#   "/v1/rooms?token=secret"
```

**Reason:** `Reference#append` (`protocol-url` `reference.rb:168`) writes the parameters into
its output, while `Reference#with(path:)` (`reference.rb:220`, path branch `:256`) passes its
argument to `Path#join`, which coerces the whole string to a path and never splits a query from
it. The two are therefore not inverses, and feeding the output of one into the other appends
the parameters a second time. `Resource#call` (`resource.rb:85`) performs exactly that
assignment, so a request that passes through a resource twice is addressed wrongly on the
second pass.

**Consequence:** this is why rule 21 requires a wrapper to perform exactly one request, and why
rule 20 puts retry in the client method, where each attempt constructs a new request whose path
is still `nil`. Those two rules are the handling for this defect; there is nothing further for
a client to do. Note the asymmetry is deliberate in `protocol-url` — `?` survives unescaped in
a path (`Path["/a?b"].to_s` is `"/a?b"`), and `Reference#initialize` documents `query` as a
separate "already-formatted query string" argument — so the round-trip was never on offer.
