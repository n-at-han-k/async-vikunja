# Style

Rules for how a client is written where the architecture permits more than one arrangement.
Each rule states what must be true, shows wrong and right code with its usage, and gives the
reason from Fielding's dissertation (cited by section) or from the HTTP
specification.

A style rule is still enforced. It is separated from `architecture.md` because breaking it
produces a conforming client that is harder to reason about, rather than a non-conforming one.

Numbering continues from `architecture.md`. Cite rule numbers when reviewing.

---

# 12. Run-time Shape Rule

**Name and arrange the client's methods after the resources and representations that exist
during an interaction, not after the API's documentation structure, its URL file layout, or its
specification's tag groupings.**

```ruby
# WRONG - mirrors the docs' sections
class Client < Async::REST::Resource
	def v2_endpoints_users_section = ...
	def admin_api_group = ...
end
```

```ruby
# RIGHT - mirrors what exists at run time
class Client < Async::REST::Resource
	def user(id) = User.new(self.with(path: "users/#{id}"))
	def users = Users.new(self.with(path: "users"))
end
```

**Reason:** §1.2.1 — "there are advantages to having the modular structure of the source code
match the decomposition of behavior within a running system". The run-time decomposition is the
resource identified by `users/1` and the representation transferred from it, so those are what
the methods are named after.

**Consequence:** this is style, not conformance. §1.2.1 holds that architectural design and
source code structural design are "separate design activities", and names advantages on both
sides — the same section allows "independent software components be implemented using parts of
the same code". A client that breaks this rule and issues correct requests still conforms by
rule 11. It is rejected here for being harder to reason about, not for being wrong.

---

# 24. One Fold Per Wrapper Rule

**When one API returns more than one response shape, give each shape its own wrapper subclass.
Never branch between shapes inside a representation's accessors.**

```ruby
# WRONG - one wrapper for both shapes, so every accessor branches
class Wrapper < Async::REST::Wrapper::Generic
	def parser_for(response)
		StreamingParser
	end
end

class Reply < Async::REST::Representation[Wrapper]
	def text
		if self.value.key?(:message)
			self.value[:message][:content]
		else
			self.value[:response]
		end
	end
end

Client.open("http://localhost:11434") do |client|
	client.chat([{role: "user", content: "hi"}]).text
	client.complete("why is the sky blue?").text
end
```

```ruby
# RIGHT - each shape has its wrapper, and each accessor reads one shape
class ChatWrapper < Wrapper
	def parser_for(response)
		case response.headers["content-type"].to_s.split(";").first
		when "application/json" then Async::REST::Wrapper::JSON::Parser
		when "application/x-ndjson" then ChatParser
		end
	end
end

class CompletionWrapper < Wrapper
	def parser_for(response)
		case response.headers["content-type"].to_s.split(";").first
		when "application/json" then Async::REST::Wrapper::JSON::Parser
		when "application/x-ndjson" then CompletionParser
		end
	end
end

class Chat < Async::REST::Representation[ChatWrapper]
	def text = self.value[:message][:content]
end

class Completion < Async::REST::Representation[CompletionWrapper]
	def text = self.value[:response]
end

Client.open("http://localhost:11434") do |client|
	client.chat([{role: "user", content: "hi"}]).text
	client.complete("why is the sky blue?").text
end
```

**Reason:** §2.3.3 — "The primary means by which architectural styles induce simplicity is by
applying the principle of separation of concerns to the allocation of functionality within
components. If functionality can be allocated such that the individual components are
substantially less complex, then they will be easier to understand and implement."

**Consequence:** this is style, not conformance. Rule 13 already requires the parser to be
selected from the declared media type, and a single wrapper that branches still obeys it. The
client is conforming either way; it is rejected here because every accessor carries the
branching that one extra wrapper removes.

---

# 25. Redacted Inspect Rule

**A representation that can hold a credential masks it in `#inspect`.**

```ruby
# WRONG - pp, exception reporters and test output print the token
class Representation < Async::REST::Representation[Wrapper]
end

Client.open("https://api.example.com/v1/") do |client|
	pp client.whoami
end
# #<Representation value={user_id: "@a:b", access_token: "supersecret", device: {token: "also-secret", id: "D1"}}>
```

```ruby
# RIGHT - the value is reported with its secrets masked
module Redacted
	SECRET = [:access_token, :refresh_token, :client_secret, :password, :token].freeze
	REDACTED = "[redacted]"

	def self.redact(value)
		case value
		when Hash
			value.to_h{|key, nested| SECRET.include?(key) ? [key, REDACTED] : [key, self.redact(nested)]}
		when Array
			value.map{|each| self.redact(each)}
		else
			value
		end
	end

	def inspect
		"\#<#{self.class} #{@resource.path.inspect} value=#{Redacted.redact(@value).inspect}>"
	end
end

class Representation < Async::REST::Representation[Wrapper]
	include Redacted
end

Client.open("https://api.example.com/v1/") do |client|
	pp client.whoami
end
# #<Representation "/v1/whoami" value={user_id: "@a:b", access_token: "[redacted]", device: {token: "[redacted]", id: "D1"}}>
```

**Reason:** not from the dissertation. The words `credential`, `password`, `confidential` and
`disclosure` appear nowhere in it, and the nearest property, visibility (§2.3.5), is about a
component's ability "to monitor or mediate the interaction between two other components" —
which REST induces deliberately and which argues the other way. §4.1.4.1 goes only as far as
requiring "that the architecture be capable of communicating authentication data". This rule
is operational: `#inspect` is called by `pp`, by exception reporters, by test output and by the
debugger, and a representation that holds a token will otherwise print it into all four.

**Consequence:** the masking applies to `#inspect` only. `#value` must keep returning the real
token, so anything that serialises the value directly still discloses it.
