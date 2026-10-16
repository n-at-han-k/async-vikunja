# Authentication

Rules for carrying credentials. Each rule states what must be true, shows wrong and right code
with its usage, and gives the reason from Fielding's dissertation (cited by section) or from the
HTTP specification.

One rule per technique. A client uses the technique its API specifies; the rules say how each is
carried, not which to choose.

Numbering continues from `architecture.md`. Cite rule numbers when reviewing.

---

# 28. Fixed Credential Rule

**A credential that does not change during the process is carried by a derived resource. Never
log in and hold the result as client state.**

```ruby
# WRONG - the credential is state, and the first request establishes it for later ones
class Client < Async::REST::Resource
	ENDPOINT = Async::HTTP::Endpoint.parse("https://firefly.example.com/api/v1/")

	def login(token)
		@token = token

		self
	end

	def about
		About.new(self.with(headers: {"authorization" => "Bearer #{@token}"}))
	end

	def accounts(type: "asset")
		Accounts.for(self.with(headers: {"authorization" => "Bearer #{@token}"}), type: type)
	end
end

Client.open do |client|
	client.login(ENV.fetch("FIREFLY_TOKEN"))

	client.about.version
end
```

```ruby
# RIGHT - the credential is part of the resource, so every derived request carries it
class Client < Async::REST::Resource
	ENDPOINT = Async::HTTP::Endpoint.parse("https://firefly.example.com/api/v1/")

	def authenticated(token)
		self.with(headers: {"authorization" => "Bearer #{token}"})
	end

	def about
		About.new(self.with(path: "about"))
	end

	def accounts(type: "asset")
		Accounts.for(self, type: type)
	end
end

Client.open do |client|
	firefly = client.authenticated(ENV.fetch("FIREFLY_TOKEN"))

	firefly.about.version
	firefly.accounts.map(&:name)
end
```

**Reason:** §5.1.3 — "each request from client to server must contain all of the information
necessary to understand the request, and cannot take advantage of any stored context on the
server." §4.1.4.1 requires "that the architecture be capable of communicating authentication
data and authorization controls". A derived resource merges its headers into every request it
makes, so the credential travels with each one; client state that each endpoint must remember
to apply is the thing that gets forgotten.

**Consequence:** the headers of a resource are merged into every request derived from it, so
`authenticated` is applied once and inherited. Where the API wants the credential in the query
instead, `self.with(parameters: {token: token})` does the same thing — parameters merge across
derivations for the same reason. Rule 27 is the other side of that default: a derivation to a
different resource has to drop parameters it should not inherit.

Three things this rule does **not** cover, each with its own technique:

- a credential that expires and must be replaced mid-process
- a request signed per request rather than carrying a token
- a credential obtained by an exchange, such as an OAuth authorization code

Those need the header computed per request rather than fixed on a resource, which `.with` cannot
express. No rule covers them yet; work one out against a running server before writing it here.
