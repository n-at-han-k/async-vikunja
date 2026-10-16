# Architecture

Rules for where conformance lives and how it is established. Each rule states what must be
true, shows wrong and right code with its usage, and gives the reason from Fielding's
dissertation (cited by section) or from the HTTP specification.

Numbering continues from `definitions.md`. Cite rule numbers when reviewing.

---

# 11. Run-time Conformance Rule

**A client conforms by the interactions it produces at run time, never by its class structure.
Establish conformance by observing the requests and responses, not by reading the source.**

```ruby
# WRONG - asserts the structure, which is not the architecture
describe Async::Tasks::Client do
	it "is correct" do
		expect(Async::Tasks::Client.superclass).to be == Async::REST::Resource
		expect(Async::Tasks::Client.instance_methods).to be(:include?, :task)
		expect(Async::Tasks::Task.superclass).to be == Async::Tasks::Representation
	end
end
```

```ruby
# RIGHT - asserts the interaction, which is
describe Async::Tasks::Client do
	include Sus::Fixtures::Async::HTTP::ServerContext

	let(:requests) {[]}

	let(:app) do
		::Protocol::HTTP::Middleware.for do |request|
			requests << {method: request.method, path: request.path, accept: request.headers["accept"]}

			::Protocol::HTTP::Response[200, {"content-type" => "application/json"}, ['{"id":1,"title":"t"}']]
		end
	end

	it "requests the identified resource and accepts JSON" do
		client = Async::Tasks::Client.open(bound_url)

		expect(client.task(1).title).to be == "t"

		expect(requests.first).to have_keys(
			method: be == "GET",
			path: be == "/tasks/1",
			accept: be == "application/json",
		)
	ensure
		client&.close
	end
end
```

**Reason:** §1.2.1 — "This raises an important distinction between software architecture and
what is typically referred to as software structure: the former is an abstraction of the
run-time behavior of a software system, whereas the latter is a property of the static software
source code." §1.3 puts a configuration "during a period of system run-time". The architecture
is therefore the interactions, and the class list is a different artefact.

**Consequence:** no arrangement of classes can establish conformance, and no arrangement can
refute it either. §1.2.1 is explicit that the two are "separate design activities" and that
there are advantages both to matching source structure to run-time decomposition and to not
matching it — "there are also advantages to having independent software components be
implemented using parts of the same code (e.g., shared libraries)". A client whose classes are
named after the vendor's documentation sections and which issues the correct requests conforms.
A client with immaculate class names that issues `GET /invoke?action=getUser` does not.

---


---

# 13. Declared Media Type Rule

**Select how to process a body from the media type the response declares. Never fix the parser
to the endpoint that was called.**

```ruby
# WRONG - the parser is fixed by the endpoint, so a translated response is parsed anyway
class Wrapper < Async::REST::Wrapper::JSON
	def parser_for(response)
		Async::REST::Wrapper::JSON::Parser
	end
end

class Task < Async::REST::Representation[Wrapper]
end

# A gateway answers with text/html:
Task.new(client.with(path: "tasks/1")).value
# => JSON::ParserError: unexpected character: '<html><body>502'
```

```ruby
# RIGHT - the parser follows what the message declares
class Wrapper < Async::REST::Wrapper::JSON
	def parser_for(response)
		if content_type = response.headers["content-type"]
			if content_type.start_with?(@content_type)
				return Async::REST::Wrapper::JSON::Parser
			end
		end

		super
	end
end

class Task < Async::REST::Representation[Wrapper]
end

# The same gateway response is left as bytes, so the caller sees what arrived:
Task.new(client.with(path: "tasks/1")).value
# => "<html><body>502 Bad Gateway</body></html>"
```

**Reason:** §5.1.5 names "self-descriptive messages" as an interface constraint, and §5.2.3
permits an intermediary to forward "with possible translation", so what arrives need not be
what the endpoint nominally returns.

---

# 14. Empty Resource Rule

**A resource with no representation of its own is a plain class holding the connection and its
identifier, constructed `.for(parent, id)`. It is not a representation.**

```ruby
# WRONG - a representation whose value can never be fetched
class Room < Async::REST::Representation[Wrapper]
	def messages
		Messages.new(@resource.with(path: "messages"))
	end
end

Room.new(client.with(path: "rooms/1")).messages

# the class is a representation, so callers reasonably read its value:
Room.new(client.with(path: "rooms/1")).value
# => Async::REST::ResponseError (405)
```

```ruby
# RIGHT - the identifier is held, and only the sub-resources are representations
class Room
	def self.for(parent, id)
		self.new(parent.with(path: "rooms/#{::Protocol::URL::Encoding.escape(id)}"), id)
	end

	def initialize(resource, id)
		@resource = resource
		@id = id
	end

	attr :id

	def messages
		Messages.new(@resource.with(path: "messages"))
	end
end

Room.for(client, "1").messages.value
# => {messages: []}
```

**Reason:** §5.2.1.1 — "A resource can map to the empty set, which allows references to be made
to a concept before any realization of that concept exists." The resource exists and is
identified; only a representation of it does not.

---

# 15. Given Identifier Rule

**Use the identifier the API publishes, exactly as published. Never normalise, reconstruct or
regularise it.**

```ruby
# WRONG - the client decides what the identifier ought to look like
class Client < Async::REST::Resource
	ENDPOINT = Async::HTTP::Endpoint.parse("https://matrix.example.com/_matrix/client/v3/")

	def room_summary(id)
		RoomSummary.new(self.with(path: "room_summary/#{id}"))
	end
end

# the summary endpoint only exists under v1, so this requests a path that does not exist
client.room_summary("!a:b").value
```

```ruby
# RIGHT - each identifier is as the API defines it
V1 = "/_matrix/client/v1"
V3 = "/_matrix/client/v3"

class Client < Async::REST::Resource
	ENDPOINT = Async::HTTP::Endpoint.parse("https://matrix.example.com")

	def room_summary(id)
		RoomSummary.new(self.with(path: "#{V1}/room_summary/#{::Protocol::URL::Encoding.escape(id)}"))
	end
end

client.room_summary("!a:b").value
```

**Reason:** §6.2.1 — "there are no resources on the server; just mechanisms that supply answers
across an abstract interface defined by resources", and semantics "are a by-product of the act
of assigning resource identifiers" by "a human naming authority". The authority that assigned
the identifier owns its shape; a client that regularises it is addressing a resource that was
never named.

---

# 16. Control Data Rule

**Honour the cache control data a response carries. A held value is a snapshot of one response,
so re-read a resource by constructing a new representation over it.**

```ruby
# WRONG - the value is reused regardless of what the response said
class Task < Async::REST::Representation[Wrapper]
	def title = self.value[:title]
end

task = Task.new(client.with(path: "tasks/1"))
task.title    # => "first"

# the server sent cache-control: no-store, and the resource has since changed
task.title    # => "first"
```

```ruby
# RIGHT - the snapshot is not reused when the response forbade it
class Task < Async::REST::Representation[Wrapper]
	def title = self.value[:title]

	def cacheable?
		if cache_control = self.metadata["cache-control"]
			!cache_control.no_store?
		else
			true
		end
	end
end

class Client < Async::REST::Resource
	def task(id)
		Task.new(self.with(path: "tasks/#{id}"))
	end
end

task = client.task(1)
task.title                          # => "first"
task = client.task(1) unless task.cacheable?
task.title                          # => "second"
```

**Reason:** §5.2.2 — "By default, the response to a retrieval request is cacheable … A component
can override these defaults by including control data that marks the interaction as cacheable,
non-cacheable or cacheable for only a limited time." §5.1.4 makes cache a constraint of the
style, so ignoring that control data drops it.

---

# 17. One Interaction Rule

**One caller action is one request wherever the API supplies the data. A collection yields
children carrying the attributes the collection already returned.**

```ruby
# WRONG - listing N items costs N+1 requests
class Tasks < Async::REST::Representation[Wrapper]
	include Enumerable

	def each
		return to_enum unless block_given?

		self.value.each do |attributes|
			yield Task.new(@resource.with(path: "../tasks/#{attributes[:id]}"))
		end
	end
end

client.tasks.map(&:title)
# one request for the listing, then one more per task
```

```ruby
# RIGHT - the attributes already received are passed to each child
class Tasks < Async::REST::Representation[Wrapper]
	include Enumerable

	def each
		return to_enum unless block_given?

		self.value.each do |attributes|
			yield Task.new(@resource.with(path: "../tasks/#{attributes[:id]}"),
				value: attributes, metadata: self.metadata)
		end
	end
end

client.tasks.map(&:title)
# one request
```

**Reason:** §5.3.3 — "a protocol that requires multiple interactions per user action, in order
to do things like negotiate feature capabilities prior to sending a content response, will be
perceptively slower than a protocol that sends whatever is most likely to be optimal first."

---

# 22. Representation Kind Rule

**A representation defines `deconstruct_keys`, and `deconstruct` when any endpoint returns an
array, so callers can discriminate which kind of representation arrived.**

```ruby
# WRONG - no hook, so no pattern matches, and [] is not value access
class Representation < Async::REST::Representation[Wrapper]
end

class Client < Async::REST::Resource
	def send_message(content)
		Representation.post(self.with(path: "messages"), {content: content})
	end
end

Client.open("https://chat.example.com/api/v1/") do |client|
	case client.send_message("hi")
	in {result: "success", id: Integer => id} then id
	end
end
# => NoMatchingPatternError
```

```ruby
# RIGHT - the kind of representation can be discriminated
class Representation < Async::REST::Representation[Wrapper]
	def deconstruct_keys(keys)
		case self.value
		in Hash => value then value
		else {}
		end
	end

	def deconstruct
		case self.value
		in Array => value then value
		else []
		end
	end
end

class Client < Async::REST::Resource
	def send_message(content)
		Representation.post(self.with(path: "messages"), {content: content})
	end
end

Client.open("https://chat.example.com/api/v1/") do |client|
	case client.send_message("hi")
	in {result: "success", id: Integer => id}
		id
	in {result: "error", code: String => code}
		raise Error, code
	end
end
# => 7
```

**Reason:** §5.2.1.2 — "Depending on the message control data, a given representation may
indicate the current state of the requested resource, the desired state for the requested
resource, or the value of some other resource, such as … a representation of some error
condition for a response." One identifier yields representations of different kinds, so a
client must discriminate which kind arrived. `#[]` cannot serve: `representation.rb:74` defines
it as `def [] **parameters` returning `self.with(parameters: parameters)`, a derived
sub-resource.

**Consequence:** a base representation defining only `deconstruct_keys` matches nothing on an
array-returning endpoint, and the `NoMatchingPatternError` names the representation rather than
the value, which reads as a broken match instead of a missing hook.

---

# 26. One Response Per Representation Rule

**A representation is one response. Anything that spans responses — a paginated collection — is
a plain class over the resource that yields page representations.**

```ruby
# WRONG - a representation whose #each walks pages, so its metadata stops describing its data
class Books < Async::REST::Representation[Wrapper]
	include Enumerable

	def each(per_page: 2)
		return to_enum(:each, per_page: per_page) unless block_given?

		page = 1

		while true
			items = self.class.get(@resource.with(parameters: {page: page, per_page: per_page}))
			records = Array(items.value)

			break if records.empty?

			records.each{|attributes| yield Book.new(@resource.with(path: "../books/#{attributes[:id]}"), value: attributes)}

			break if records.size < per_page

			page += 1
		end
	end
end

class Client < Async::REST::Resource
	def books = Books.new(self.with(path: "books"))
end

Client.open("https://api.example.com/v1/") do |client|
	books = client.books

	books.map(&:title)
	# => ["Dune", "Solaris", "Blindsight"]

	# but the object holds page 1 only:
	books.value.size                    # => 2
	books.metadata["last-modified"]     # => "page-1"
end
```

```ruby
# RIGHT - each page is a representation; the walker is not
class Page < Async::REST::Representation[Wrapper]
	include Enumerable

	def each
		return to_enum unless block_given?

		self.value.each do |attributes|
			yield Book.new(@resource.with(path: "../books/#{attributes[:id]}"),
				value: attributes, metadata: self.metadata)
		end
	end
end

class Books
	include Enumerable

	def self.for(parent)
		self.new(parent.with(path: "books"))
	end

	def initialize(resource)
		@resource = resource
	end

	def each_page(per_page: 2)
		return to_enum(:each_page, per_page: per_page) unless block_given?

		page = 1

		while true
			books = Page.get(@resource.with(parameters: {page: page, per_page: per_page}))
			records = Array(books.value)

			break if records.empty?

			yield books

			break if records.size < per_page

			page += 1
		end
	end

	def each(**options, &block)
		return to_enum(:each, **options) unless block_given?

		self.each_page(**options){|page| page.each(&block)}
	end
end

class Client < Async::REST::Resource
	def books = Books.for(self)
end

Client.open("https://api.example.com/v1/") do |client|
	client.books.map(&:title)
	# => ["Dune", "Solaris", "Blindsight"]   2 requests

	client.books.take(2).map(&:title)
	# => ["Dune", "Solaris"]                 1 request

	client.books.each_page.to_a.each do |page|
		page.value.size                 # => 2, then 1
		page.metadata["last-modified"]  # => "page-1", then "page-2"
	end
end
```

**Reason:** §5.2.1.2 — "A representation is a sequence of bytes, plus representation metadata to
describe those bytes." One sequence, one set of metadata describing those bytes, and Table 5-1
gives that metadata as "media type, last-modified time" — both per message. A collection that
walks pages holds the first response's bytes and headers while yielding items from every
response, so its metadata no longer describes its data. There is no `last-modified` for thirty
pages, because thirty responses carried thirty of them.

**Consequence:** rule 14 already names what such an object is — a resource with no
representation of its own, so a plain class holding the connection and its identifier. Yielding
each page as its own representation keeps every value paired with the metadata that describes
it, and `take(2)` still costs one request, so network efficiency (§2.3.1.3 — "reduction of the
frequency of network interactions in relation to user actions") is preserved without a
representation having to lie about what it holds.

---

# 27. Independent Identifier Rule

**A child derived from a collection carries none of the collection's parameters. Pass both
`parameters: nil` and `merge: false` when deriving it.**

```ruby
# WRONG - the collection's filter and paging follow the child
class AccountPage < Representation
	include Enumerable

	def each
		return to_enum unless block_given?

		Array(self.data).each do |record|
			resource = @resource.with(path: "../accounts/#{record[:id]}")

			yield Account.new(resource, value: {data: record}, metadata: self.metadata)
		end
	end
end

Client.open("https://firefly.example.com/api/v1/") do |client|
	account = client.accounts(type: "asset").first

	account.resource.reference.to_s
	# => "/api/v1/accounts/7?type=asset&page=1&limit=100"

	# so re-reading the account sends the collection's paging to a single-account endpoint
	Account.new(account.resource).name
end
```

```ruby
# RIGHT - the child is identified on its own terms
class AccountPage < Representation
	include Enumerable

	def each
		return to_enum unless block_given?

		Array(self.data).each do |record|
			resource = @resource.with(path: "../accounts/#{record[:id]}", parameters: nil, merge: false)

			yield Account.new(resource, value: {data: record}, metadata: self.metadata)
		end
	end
end

Client.open("https://firefly.example.com/api/v1/") do |client|
	account = client.accounts(type: "asset").first

	account.resource.reference.to_s
	# => "/api/v1/accounts/7"

	Account.new(account.resource).name
end
```

**Reason:** §5.2.1.1 — a mapping to "the paper published in the proceedings of conference X"
and one to the "authors' preferred version" are "two distinct resources, even if they both map
to the same value at some point in time. The distinction is necessary so that both resources
can be identified and referenced independently." A collection and one of its members are two
such resources, so the member's identifier cannot be the collection's identifier with a path
appended.

**Consequence:** both arguments are needed, because neither alone clears the query.
`Reference#with` takes `parameters: false` as its "none given" sentinel, which is distinct from
`nil`, and `merge: true` by default:

```
starting reference: "/api/v1/accounts?type=asset&page=1"

with(path: "7")                                  => "/api/v1/accounts/7?type=asset&page=1"
with(path: "7", parameters: nil)                 => "/api/v1/accounts/7?type=asset&page=1"
with(path: "7", merge: false)                    => "/api/v1/accounts/7?type=asset&page=1"
with(path: "7", parameters: nil, merge: false)   => "/api/v1/accounts/7"
```

`merge: false` alone keeps the existing parameters, because replace mode with nothing to
replace them with falls back to them. `parameters: nil` alone is restored by merge mode. The
merging default is deliberate and load-bearing — it is what lets rule 28 put a credential in a header or the
query once and have every later derivation carry it — which is exactly why a derivation to a
different resource has to opt out.
