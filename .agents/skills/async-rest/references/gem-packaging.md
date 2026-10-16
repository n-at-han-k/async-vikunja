# Packaging the client as a gem

Read this when the client is going out as a published gem rather than living inside an
application. It describes the conventions the Async ecosystem uses, so a new client looks
native alongside the others — which matters mostly because contributors and tooling
(`bake`, `sus`, `covered`, `utopia-project`) expect this layout.

If you're just dropping a client into an existing app, you don't need any of this. Put the
classes somewhere sensible and skip ahead.

## Layout

```
async-example/
├── async-example.gemspec
├── gems.rb                      # the Gemfile, named gems.rb by convention
├── bake.rb                      # project tasks and release hooks
├── readme.md                    # lowercase
├── license.md
├── releases.md                  # changelog, newest first
├── config/
│   └── sus.rb                   # test harness configuration
├── lib/
│   └── async/
│       ├── example.rb           # entry point: requires version + client
│       └── example/
│           ├── client.rb
│           ├── representation.rb
│           ├── wrapper.rb
│           ├── version.rb
│           └── <endpoint>.rb    # one file per resource family
├── fixtures/
│   └── async/example/
│       └── client_context.rb    # shared test fixtures, on the load path
├── test/
│   └── async/example/
│       └── client.rb            # mirrors lib/ layout; no _test suffix
└── guides/
		└── getting-started/
				└── readme.md
```

Two conventions that surprise people: tests live in `test/` but are named after the thing
they test with no suffix, and shared test fixtures live in a top-level `fixtures/` directory
that gets added to the load path so tests can `require "async/example/client_context"`.

## Code style

- **Tabs for indentation**, in Ruby and in the Markdown code blocks of guides.
- `# frozen_string_literal: true` as the first line, then a blank line, then the licence
  header comment, then a blank line, then the requires.
- `require` for other gems, `require_relative` within the gem.
- Namespace everything under `Async::<Name>`.
- Document public methods with `@parameter` / `@returns` tags — `decode` reads these to
  generate the API documentation, and `utopia-project` renders them.

A typical file header:

```ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Your Name.

require "async/rest/representation"

require_relative "wrapper"

module Async
	module Example
		# Represents a user.
		class User < Representation
			# @returns [String] The user's display name.
			def name
				self.value[:name]
			end
		end
	end
end
```

## The gemspec

```ruby
# frozen_string_literal: true

require_relative "lib/async/example/version"

Gem::Specification.new do |spec|
	spec.name = "async-example"
	spec.version = Async::Example::VERSION

	spec.summary = "A client for the Example API."
	spec.authors = ["Your Name"]
	spec.license = "MIT"

	spec.homepage = "https://github.com/you/async-example"

	spec.metadata = {
		"documentation_uri" => "https://you.github.io/async-example/",
		"source_code_uri" => "https://github.com/you/async-example.git",
	}

	spec.files = Dir.glob(["{context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)

	spec.required_ruby_version = ">= 3.3"

	spec.add_dependency "async-rest", "~> 0.20"
end
```

Pin `async-rest` with a pessimistic constraint on the minor version. The gem is pre-1.0 and
minor releases do change the API, so `~> 0.20` tracks patches without inheriting a
breaking change.

## gems.rb

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "sus-fixtures-async-http"
	gem "bake-test"
end
```

## Tests with sus

`config/sus.rb` wires in coverage:

```ruby
# frozen_string_literal: true

require "covered/sus"
include Covered::Sus
```

`sus` describes with `describe`/`with`/`it`, uses `let` for lazily-memoized values, and
expects with `expect(…).to be == …`. The matchers differ from RSpec: `be ==`, `be_a`,
`have_keys`, `have_attributes`, `be(:include?, x)`, and `not.to` rather than `to_not`.

```ruby
# frozen_string_literal: true

require "async/example/client_context"

describe Async::Example::Client do
	include Async::Example::ClientContext

	with "#user" do
		it "can fetch a user" do
			user = client.user("test")

			expect(user.value).to have_keys(:id, :name)
			expect(user.name).to be == "Test User"
		end
	end
end
```

Run with `bundle exec sus`, or a single file with `bundle exec sus test/async/example/client.rb`.

### Shared contexts and shared behaviours

A `Sus::Shared` block is reusable setup. Put connection boilerplate in `fixtures/` so every
test file gets it the same way:

```ruby
# frozen_string_literal: true

require "async/example/client"
require "sus/fixtures/async/http/server_context"

module Async
	module Example
		ClientContext = Sus::Shared("client context") do
			include Sus::Fixtures::Async::HTTP::ServerContext

			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200,
						{"content-type" => "application/json"},
						[JSON.dump({id: 1, name: "Test User"})]
					]
				end
			end

			let(:client) {Async::Example::Client.open(bound_url)}

			after do
				@client&.close
			end
		end
	end
end
```

Prefer a stub server over hitting the live API. A suite that needs real credentials can't
run in CI, can't run offline, and fails for reasons that have nothing to do with your code.
If you do want a smoke test against the real service, keep it in a separate file guarded by
an environment variable so the default suite stays hermetic.

## bake.rb

`bake` is the task runner. The release hooks keep the changelog and docs in step with the
version:

```ruby
# frozen_string_literal: true

# Update the project documentation with the new version number.
#
# @parameter version [String] The new version number.
def after_gem_release_version_increment(version)
	context["releases:update"].call(version)
	context["utopia:project:update"].call
end
```

Custom tasks live in `bake/<namespace>.rb` and become `bake <namespace>:<method>`:

```ruby
# bake/async/example.rb — invoked as `bake async:example:whoami`
# frozen_string_literal: true

def initialize(...)
	super

	require "async/example/client"
end

# Print the authenticated user.
def whoami
	Async::Example::Client.open do |client|
		puts client.authenticated(ENV.fetch("EXAMPLE_TOKEN")).user("@me").name
	end
end
```

This is a good place to put the smoke test you'd otherwise be tempted to write as a spec:
it exercises the real API on demand without making the test suite depend on credentials.

## Documentation

`guides/<topic>/readme.md` holds prose guides, rendered by `utopia-project`. Cross-reference
API entities with `{ruby Async::Example::Client}` so links resolve. Start with a
`guides/getting-started/readme.md` covering installation, authentication and one worked
example — that single page is what most people will read, so make the example complete
enough to copy and run.

Keep `releases.md` newest-first, with one section per version and a bullet per user-visible
change. `bake releases:update` maintains it as part of the release flow.
