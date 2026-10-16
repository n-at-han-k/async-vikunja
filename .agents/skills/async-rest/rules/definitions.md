# Definitions

Rules for building an `async-rest` client. Each rule states what must be true, shows wrong
and right code with its usage, and gives the reason from Fielding's dissertation (cited
by section) or from the HTTP specification.

Rules 1-3 define the three things a client handles. Everything after them depends on those
definitions. Cite rule numbers when reviewing.

---

# 1. Resource Is A Connection Rule

**A resource object represents a remote connection and the identifier used over it. It is not
the data.**

```ruby
# WRONG - a resource holding bytes; it is the data, so it is a file
class Resource
	def initialize(url, bytes)
		@url = url
		@bytes = bytes
	end

	attr :bytes
end

resource = Resource.new("https://api.example.com/v1/users/1", File.read("cached.json"))
::JSON.parse(resource.bytes)
```

```ruby
# RIGHT - a connection and an identifier over it
class Resource < ::Protocol::HTTP::Middleware
	def initialize(delegate, reference, headers)
		super(delegate)

		@reference = reference
		@headers = headers
	end
end

Client.open do |client|
	client.with(path: "users/1")
end
```

**Reason:** §6.2.1 — the pre-REST definition made an identifier name a document, which fails
because it "would imply that the identifier should change whenever the content changes". The
word was kept and redefined; a `Resource` holding bytes reimports the definition that was
discarded.

---

# 2. Representation Is A Wrapper Rule

**A representation object represents the transport wrapper around data — the bytes together
with their metadata. It is not the data.**

```ruby
# WRONG - the representation IS the parsed data; the metadata is gone
class Representation < Hash
	def self.for(response)
		self[::JSON.parse(response.read, symbolize_names: true)]
	end
end

representation = Representation.for(response)
representation[:name]
```

```ruby
# RIGHT - the wrapper: data, its metadata, and the name it came from
class Representation
	def initialize(resource, value: nil, metadata: {})
		@resource = resource
		@value = value
		@metadata = metadata
	end

	attr :metadata
	attr :value
end

representation = Representation.new(resource, value: response.read, metadata: response.headers)
representation.metadata["content-type"]
```

**Reason:** §5.2.1.2 lists `document`, `file`, `entity`, `instance` and `variant` as "less
precise" names, and §6.2.5 gives the imprecision: a file is "a named sequence of bytes",
whereas "both data and metadata are included within, and significant to, the semantics of a
representation". A representation that is its data has become one of the rejected names.

---

# 3. Data Carries No Metadata Rule

**The data is what the parser produces from the wrapper. It carries no metadata and no
identity — those are read from the representation.**

```ruby
# WRONG - metadata folded into the data; the value now lies about itself
class Parser < ::Protocol::HTTP::Body::Wrapper
	def join
		::JSON.parse(super, symbolize_names: true).merge(content_type: "application/json")
	end
end

value = Parser.new(body).join
value[:content_type]
```

```ruby
# RIGHT - the parser produces data only; metadata stays on the wrapper
class Parser < ::Protocol::HTTP::Body::Wrapper
	def join
		::JSON.parse(super, symbolize_names: true)
	end
end

representation = User.get(resource)
representation.value[:name]
representation.metadata["content-type"]
```

**Reason:** The WRONG version hardcodes what rule 2 says the wrapper carries, so the data
asserts a type nobody checked — and it collides with any field the API genuinely calls
`content_type`. Metadata is defined per field by the RFC, which is why it is read through the
accessor on the representation.

---

# 4. Visible Target Rule

**The thing being acted on appears in the request identifier, not in a payload. One endpoint
must not stand in for many targets.**

```ruby
# WRONG - every action is one endpoint; an intermediary sees only "/invoke"
class Client
	def initialize(connection)
		@connection = connection
	end

	def call(operation, **arguments)
		@connection.post("/invoke", {operation: operation, arguments: arguments})
	end
end

client = Client.new(connection)
client.call("User.fetch", id: 1)
client.call("User.rename", id: 1, name: "Bea")
```

```ruby
# RIGHT - the target is the identifier
class Client < Async::REST::Resource
	ENDPOINT = Async::HTTP::Endpoint.parse("https://api.example.com/v1/")

	def user(id)
		self.with(path: "users/#{id}")
	end
end

Client.open do |client|
	User.get(client.user(1))
	User.put(client.user(1), {name: "Bea"})
end
```

**Reason:** Distributed objects were rejected partly because "it is difficult to obtain an
overall view of system activity (poor visibility)" (§3.6.3), and §4.1.4.1 requires that
intermediaries "be able to inspect the application interactions and prevent those outside the
security policy of the organization from being acted upon". A target hidden in a payload cannot
be inspected.

---

# 5. Self-Sufficient Name Rule

**A name is usable on its own. It is never a handle obtained from a prior exchange.**

```ruby
# WRONG - the name is a server-issued handle; it depends on a previous request
class Client
	def initialize(connection)
		@connection = connection
	end

	def open_user(id)
		@handle = @connection.post("/open", {id: id})[:handle]
	end

	def read_user
		@connection.post("/read", {handle: @handle})
	end
end

client = Client.new(connection)
client.open_user(1)
client.read_user
```

```ruby
# RIGHT - the name stands alone; no prior request
class Client < Async::REST::Resource
	ENDPOINT = Async::HTTP::Endpoint.parse("https://api.example.com/v1/")

	def user(id)
		self.with(path: "users/#{id}")
	end
end

Client.open do |client|
	resource = client.user(1)

	User.get(resource)
end
```

**Reason:** §3.6.3 found that in object systems "when the identity of an object changes, it is
necessary to modify all other objects that explicitly invoke it", and §4.1.4.1 states "Clients
cannot be expected to maintain knowledge of all servers" — across organisational boundaries you
cannot reach the holders of a name to reissue it.

---

# 6. Streamable Data Rule

**Representation data is kept as a stream. It is not read to completion in order to be held.**

```ruby
# WRONG - the body is drained at construction; nothing can be consumed incrementally
class Representation
	def initialize(resource, response)
		@resource = resource
		@value = response.body.read
		@metadata = response.headers
	end
end

Wrapper.new.call(resource, "GET") do |response|
	Representation.new(resource, response)
end
```

```ruby
# RIGHT - the body is wrapped, so it stays a stream
class Wrapper < Async::REST::Wrapper::Generic
	def wrap_response(response)
		if body = response.body
			if parser = self.parser_for(response)
				response.body = parser.new(body)
			end
		end

		return response
	end
end

Completion.post(resource, {prompt: "why is the sky blue?"}) do |resource, response|
	response.body.each do |chunk|
		$stdout.write(chunk)
	end

	Completion.new(resource, value: response.read, metadata: response.headers)
end
```

**Reason:** §3.6.3 rejected object systems in part because "data streaming is not supported in
general", and §4.1.3 requires the opposite: "user actions … require the transfer of large
amounts of data from where the data is stored to where it is used. Thus, the Web architecture
must be designed for large-grain data transfer."

---

# 7. Two Objects Rule

**A name and the data fetched through it are separate objects.**

```ruby
# WRONG - one object is both the name and the data
class UserResource
	def initialize(connection, path)
		@connection = connection
		@path = path
		@value = nil
	end

	def value
		@value ||= @connection.get(@path)
	end
end

user = UserResource.new(connection, "/users/1")
user.value
```

```ruby
# RIGHT - the name exists first; the data is a second object
Client.open do |client|
	resource = client.user(1)
	representation = User.get(resource)

	representation.value
end
```

**Reason:** By rule 5 a name must be usable with no prior exchange, so a name exists before any
transfer. Data exists only as the result of a transfer. One object cannot both pre-date a
transfer and be its product.

---

# 8. Name Contents Rule

**The name object holds the identifier and the connector. Nothing else.**

```ruby
# WRONG - the name also holds data
class Resource < ::Protocol::HTTP::Middleware
	def initialize(delegate, reference, headers)
		super(delegate)

		@reference = reference
		@headers = headers
		@value = nil
	end
end

resource = Resource.new(delegate, reference, headers)
resource.instance_variable_get(:@value)
```

```ruby
# RIGHT - identifier and connector only, so deriving a name costs nothing
class Resource < ::Protocol::HTTP::Middleware
	def initialize(delegate, reference, headers)
		super(delegate)

		@reference = reference
		@headers = headers
	end
end

resource = Resource.new(delegate, reference, headers)
derived = resource.with(path: "users/1")
```

**Reason:** Rule 7 requires the identifier. Rule 5 requires the name be usable alone, so it must
hold the means of use — the connector. Rule 7 forbids data. Those three leave exactly identifier
plus connector.

---

# 9. Data Contents Rule

**The data object holds the data, the metadata needed to interpret it, and the name it came
from. It does not hold a connector.**

```ruby
# WRONG - carries its own connector and path, duplicating the name's job
class Representation
	def initialize(connection, path, value)
		@connection = connection
		@path = path
		@value = value
	end
end

Representation.new(connection, "/users/1", {name: "Bea"})
```

```ruby
# RIGHT - data, its metadata, and the name it is data for
class Representation
	def initialize(resource, value: nil, metadata: {})
		@resource = resource
		@value = value
		@metadata = metadata
	end
end

Representation.new(resource, value: {name: "Bea"}, metadata: response.headers)
```

**Reason:** Rule 6 requires the data be streamable, which needs something to interpret the
stream — the metadata. Rule 7 makes it a second object, so it must say which name it is data
for. Rule 8 already owns the connector, so holding another would mean two objects reaching the
network for one name.

---

# 10. Metadata Access Rule


**Read a header through the accessor and use the type it returns. Never assume a header's value
is a String, never `.split(",")` it yourself, and never compare it with `==` without knowing its
cardinality.**

```ruby
# WRONG - assumes String
class Representation
	def cacheable?
		!@metadata["cache-control"].include?("no-store")
	end

	def media_type
		@metadata["content-type"].split(";").first
	end
end
```

```ruby
# RIGHT - uses what the accessor returns
class Representation
	def cacheable?
		if cache_control = @metadata["cache-control"]
			!cache_control.no_store?
		else
			true
		end
	end

	def media_type
		@metadata["content-type"]&.split(";")&.first
	end
end
```

**Reason:** The RFC defines cardinality and syntax per field, not globally, so the field name is
the only thing that tells you the shape. `protocol-http` encodes those per-field rules as types,
and one accessor returns all of them:

```
etag           -> Protocol::HTTP::Header::ETag          "\"/nathan
  ⎿  Allowed by auto mode classifier

● Works. Replacing the weakness section with the extension, and correcting the false claim about unmodelled fields.

● Bash(SP=/tmp/claude-1001/-home-nathan/20f096b5-2657-4da9-badc-503b1d8afe47/scratchpad
      cd ~/usb/agent-skill-async-rest 2>/dev/null…)
  ⎿  rules/metadata-access.md: 131 lines

       1:# Metadata Access Rule
     … +7 lines (ctrl+o to expand)
  ⎿  Allowed by auto mode classifier

● Replaced. The file now ends with working code instead of a caveat.

  Two corrections went in:

  The weakness claim was factually wrong. I said an unmodelled field "returns a bare String". It returns
  Header::Generic, because POLICY has default = Header::Generic, and that's an Array subclass. So coverage was never
  the gap.

  The actual gap is narrower and fixable, and the file now shows how: Generic accumulates repeats, which is right for a
  list-valued field and wrong for a singleton. So when your standard defines a field as one value, or defines a
  syntax, you register a policy — a class with self.parse and self.coerce, keyed by lowercase field name:

  Protocol::HTTP::Headers::POLICY["x-ratelimit-remaining"] = Async::Example::Header::Count

  Tested before writing it:

  single value    -> Async::Example::Header::Count   to_i: 42
  after duplicate -> ["42", "41"]                    to_i: 41

  to_i taking the last value is the singleton rule from the standard expressed once, in the field's class, instead of
  at every call site — which is the same reason the rule exists at all.

  I also kept the operational constraints that make it usable rather than aspirational: register at require time before
  any request, POLICY is a plain unfrozen Hash, the registration is process-global, and don't override a field
  protocol-http already defines unless your standard genuinely differs from the RFC.

  rules/metadata-access.md is 131 lines: the rule, the wrong/right pair, why it's the only correct handling, and the
  extension. Still carrying the dependency note at the top, since it presumes Representation and Resource — neither
  agreed.

✻ Cooked for 1m 21s · done 22:50

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ 
───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  ⏵⏵ auto mode on (shift+tab to cycle) · ← 5 agentsv1\""
content-type   -> String                                "application/json"
cache-control  -> Protocol::HTTP::Header::CacheControl  ["no-store"]
accept         -> Protocol::HTTP::Header::Accept        ["application/json", "text/html"]
vary           -> Protocol::HTTP::Header::Vary          ["accept"]
retry-after    -> String                                "120"
set-cookie     -> Protocol::HTTP::Header::SetCookie     ["a=1"]
```

## Why this is the only correct handling

Three facts force it:

1. **The RFC defines semantics per field name.** Dissertation §5.2.1.2 defers to it — metadata is
   pairs "where the name corresponds to a standard that defines the value's structure and
   semantics." There is no general rule for "a header", only rules for each header.
2. **Cardinality is not inferable from the value.** `cache-control: no-store` is a one-element
   list; `retry-after: 120` is a singleton. Both look like one token. Only the field name
   distinguishes them.
3. **HTTP gives no syntactic marker.** §6.3.4.4: the protocol "fails to syntactically distinguish
   between representation metadata and message control information (both transmitted as header
   fields)." Nothing in the wire format tells you which kind of thing you hold.

So any approach that treats headers uniformly — stringify, split on commas, compare directly —
is wrong for some subset of fields by construction. The field name must drive the handling,
which means deferring to the accessor that already knows the field.

**Consequence:** `@metadata["cache-control"].include?("no-store")` in the WRONG example happens
to work, because `CacheControl` is Array-like. The same code on `retry-after` is a substring test
on a String, and on `content-type` `.split(";")` works but raises on a missing header. Uniform
handling fails silently in a different way per field.

## A field your standard defines but `protocol-http` does not

An unregistered field is not a String — `Headers::POLICY` has
`default = Header::Generic`, so an unknown field comes back as a `Generic`, which is an
`Array` subclass:

```
x-ratelimit-remaining  ->  Protocol::HTTP::Header::Generic  ["42", "41"]
```

That is correct for a list-valued field and wrong for a singleton, because `Generic`
accumulates repeats. When your API's standard defines a field as a single value, or defines a
syntax to parse, register a policy for it.

A policy is either `false`, meaning the field appears once and is a plain String, or a class
implementing `self.parse(value)` and `self.coerce(value)`. Register it by field name, in
lowercase:

```ruby
module Async
	module Example
		module Header
			# x-ratelimit-remaining is defined by its standard as one integer.
			class Count < ::Protocol::HTTP::Header::Generic
				def self.parse(value)
					self.new(value)
				end

				def to_i
					self.last.to_i
				end
			end
		end
	end
end

Protocol::HTTP::Headers::POLICY["x-ratelimit-remaining"] = Async::Example::Header::Count
```

Verified:

```
single value    -> Async::Example::Header::Count   to_i: 42
after duplicate -> ["42", "41"]                    to_i: 41
```

`to_i` returning the last value is the standard's rule for a singleton field expressed in code,
which is the point: the field's definition lives in one place instead of at every call site.

Register the policy where the library is required, before any request is made. `POLICY` is a
plain Hash and is not frozen, and the registration is global to the process — so name the field
exactly, and do not re-register a field `protocol-http` already defines unless your standard
genuinely differs from the RFC.

