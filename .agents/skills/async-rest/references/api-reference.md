# Async::REST API reference

The exact public surface of `async-rest` v0.20. Consult this to confirm a signature rather
than guessing one — several methods have names that suggest a different shape than they have
(notably the HTTP verbs, which are class methods on representations).

## Contents

- [Requiring](#requiring)
- [Resource](#resource)
- [Path and parameter semantics](#path-and-parameter-semantics)
- [Representation](#representation)
- [Representation::Mutable](#representationmutable)
- [Wrapper::Generic](#wrappergeneric)
- [Wrapper::JSON](#wrapperjson)
- [Wrapper::URLEncoded](#wrapperurlencoded)
- [Wrapper::Form](#wrapperform)
- [Errors](#errors)
- [Request lifecycle](#request-lifecycle)

## Requiring

`require "async/rest"` pulls in `Representation` and all three wrappers. The narrower requires
are `async/rest/resource`, `async/rest/representation`, `async/rest/wrapper/json`,
`async/rest/wrapper/url_encoded` and `async/rest/wrapper/form`.

Dependencies: `async-http ~> 0.42`, `protocol-url ~> 0.2`. Requires Ruby >= 3.3.

## Resource

`Async::REST::Resource < Protocol::HTTP::Middleware`. Holds a connection, a URL reference and
default headers.

| Member | Description |
|---|---|
| `ENDPOINT` | Constant, `nil` on the base class. Subclasses set it to an `Async::HTTP::Endpoint`; `.open` uses it as the default. |
| `.open(endpoint = self::ENDPOINT, **options)` | Creates a resource. A `String` endpoint is parsed with `Async::HTTP::Endpoint.parse`. Without a block, returns the resource (caller must `#close`). With a block, wraps it in `Sync` and closes the resource in an `ensure`, returning the block's value. |
| `.connect(endpoint)` | Returns `[client, reference]`. The client is an `Async::HTTP::Client` wrapped in `Protocol::HTTP::AcceptEncoding`; the reference is parsed from `endpoint.path`. Override to change connection setup. |
| `.with(parent, headers: {}, **options)` | Builds a resource from a parent: same delegate, `parent.reference.with(**options)`, and `parent.headers.merge(headers)`. |
| `#initialize(delegate, reference = Protocol::URL::Reference.parse, headers = Protocol::HTTP::Headers.new)` | |
| `#with(**options)` | The workhorse. Returns a new resource of the same class sharing this connection. Accepts `path:`, `parameters:`, `headers:` and anything else `Protocol::URL::Reference#with` takes. |
| `#reference` | The `Protocol::URL::Reference`. |
| `#headers` | The default `Protocol::HTTP::Headers`. |
| `#path` | `reference.path`. |
| `#call(request)` | Sets `request.path` from the reference, merges the default headers under the request's own, then delegates. |
| `#close` | From `Middleware` — closes the underlying client. |
| `#delegate` | From `Middleware` — the next middleware or client. |

Because `#with` returns `self.class.new(...)`, a `Client` subclass derives more `Client`s, and
domain methods stay available on every derived resource.

## Path and parameter semantics

Supplied by `protocol-url`. Worth knowing precisely, because these rules decide whether your
client's URLs come out right.

| Base reference | `with(path: …)` | Result |
|---|---|---|
| `/api/v1/` | `"users"` | `/api/v1/users` |
| `/api/v1` | `"users"` | `/api/v1/users` |
| `/api/v1/` | `"/users"` | `/users` |
| `/api/v1/users` | `"123"` | `/api/v1/users/123` |
| `/api/v1/users/123` | `"../456"` | `/api/v1/users/456` |

A trailing slash on the base makes no difference — both forms append. A **leading** slash on
the argument replaces the whole path, which is how you accidentally drop a version prefix.

Parameters **merge** across successive `#with` calls rather than replacing:

```ruby
client.with(parameters: {token: "t"}).with(path: "search", parameters: {q: "x"})
# => /api/v1/search?token=t&q=x
```

Headers merge the same way, with the newly supplied header winning on a key collision.

## Representation

`Async::REST::Representation`. One instance is one endpoint's response.

| Member | Description |
|---|---|
| `WRAPPER` | Constant holding the wrapper **instance**. Defaults to `Wrapper::JSON.new`. |
| `.[](wrapper)` | Returns an anonymous subclass with `WRAPPER` set. Accepts a wrapper class (instantiated for you) or an instance. This is the idiomatic binding: `class Thing < Async::REST::Representation[MyWrapper]`. |
| `.get`, `.head`, `.post`, `.put`, `.delete`, `.patch`, `.options`, `.trace`, `.connect`, `.query` | Class methods, each `(resource, payload = nil, &block)`. Generated from `Protocol::HTTP::Methods`. They call the wrapper and pass the response to `.for`. **None of them checks the response status.** |
| `.for(resource, response, &block)` | Without a block, returns `new(resource, value: response.read, metadata: response.headers)`. With a block, yields `(resource, response, self)` and returns the block's value — the hook for streaming or for building something other than a representation. |
| `#initialize(resource, value: nil, metadata: {})` | Passing `value:` pre-seeds the representation so no request is made. |
| `#value` | `@value ||= get`. The lazy fetch issues a `GET` through the wrapper, and **raises `ResponseError` unless `response.success?`**. |
| `#value?` | Whether a value is already present, without fetching. |
| `#metadata` | Response headers, set when a value is fetched (or passed to `#initialize`). |
| `#resource` | The underlying resource. |
| `#with(klass = nil, **options)` | Returns a representation over `@resource.with(**options)` — of `klass` if given, otherwise of `self.class`. Note it does **not** carry the current value across. |
| `#[](**parameters)` | Shorthand for `with(parameters: parameters)`. |
| `#close` | Closes the underlying resource. |

The status-check asymmetry between `#value` and the class-level methods is the most
consequential detail in the library. See Step 5 of `SKILL.md`.

## Representation::Mutable

An opt-in mixin; writes are not available on instances unless you include it.

| Member | Description |
|---|---|
| `#post(value)` | Posts `value`, replaces `@value` with the response body, returns `self`. |
| `#delete` | Delegates to the class-level `.delete`. |
| `#assign(value)` | `post(value)` when `value` is truthy, otherwise `delete` — models "set or clear". |

## Wrapper::Generic

`Async::REST::Wrapper::Generic` is the base for all wrappers. Override the two hooks; leave
the lifecycle alone. Rule 21 requires `response_for` to perform exactly one request.

| Member | Description |
|---|---|
| `#call(resource, method = "GET", payload = nil, &block)` | The lifecycle: builds a `Protocol::HTTP::Request`, calls `prepare_request`, gets a response via `response_for`, calls `process_response`, then yields the response. If the block raises, the response is closed before the exception propagates, so connections aren't left dangling. |
| `#prepare_request(request, payload)` | **Override this.** Set `request.headers["accept"]`, and when `payload` is non-nil set `request.headers["content-type"]` and `request.body`. The default wraps `payload` with `Protocol::HTTP::Body::Buffered.wrap`. |
| `#parser_for(response)` | **Override this.** Return a `Protocol::HTTP::Body::Wrapper` subclass to parse the body, or `nil` to leave it as-is. The default returns `nil`. |
| `#process_response(request, response)` | Calls `wrap_response`. Override to validate a response — raising on an unexpected content type, for instance. |
| `#wrap_response(response)` | Replaces `response.body` with `parser_for(response).new(body)`, but only when a parser is found and a body is present. |
| `#response_for(resource, request)` | Sends the request, and on a `429` with a `retry-after` header sleeps and retries in a loop. The replayed request is corrupted (rule 23), so rule 21 requires overriding this to perform exactly one request; retry belongs in the client method (rule 20). |
| `#retry_after_duration(value)` | Parses `retry-after` as an HTTP-date (clamped at `0`) or, failing that, as a float number of seconds. |
| `Generic::Unsupported` | A body wrapper whose `#join` raises `UnsupportedError`. Return it from `parser_for` to make a content type explicitly unreadable. |

## Wrapper::JSON

| Member | Description |
|---|---|
| `APPLICATION_JSON` | `"application/json"`. |
| `APPLICATION_JSON_STREAM` | `"application/json; boundary=NL"`. |
| `#initialize(content_type = APPLICATION_JSON)` | Pass a vendor type here to negotiate it. |
| `#content_type` | The negotiated type. |
| `#prepare_request` | Sets `accept` (only if unset), and for a non-nil payload sets `content-type` and dumps the payload with `JSON.dump`. |
| `JSON::Parser` | Body wrapper whose `#join` is `JSON.parse(super, symbolize_names: true)` — hence symbol keys everywhere. |
| `#parser_for(response)` | Returns `Parser` when the response's `content-type` starts with `#content_type`. |

## Wrapper::URLEncoded

Same shape as `JSON`, with `APPLICATION_FORM_URLENCODED` (`"application/x-www-form-urlencoded"`).
Encodes payloads with `Protocol::URL::Encoding.encode` and its `Parser#join` decodes with
`Protocol::URL::Encoding.decode(symbolize_keys: true)`.

## Wrapper::Form

For APIs that accept form-encoded requests but may answer with either JSON or form data.

| Member | Description |
|---|---|
| `DEFAULT_CONTENT_TYPES` | `{"application/json" => JSON::Parser, "application/x-www-form-urlencoded" => URLEncoded::Parser}`. |
| `#initialize(content_types = DEFAULT_CONTENT_TYPES)` | Pass your own map to negotiate vendor types — the keys become `accept` headers and the values are the parsers. |
| `#prepare_request` | Adds every key as an `accept` header; sends payloads form-encoded. |
| `#parser_for(response)` | Splits the response `content-type` on `;` and looks the media type up in the map. |

## Errors

All descend from `Async::REST::Error < StandardError`.

| Class | Raised when |
|---|---|
| `Error` | Base class — rescue this to catch everything from the library. |
| `ResponseError` | A lazy `#value` fetch got a non-success status. `#response` is the response; `#message` is the body; `#to_s` prefixes the response. |
| `UnsupportedError` | A body wrapped in `Generic::Unsupported` was joined. |
| `RequestError` | Defined for use by clients; not raised by the library itself. |

## Request lifecycle

Useful when tracing where to intervene:

```
Representation.post(resource, payload, &block)
	└─ WRAPPER.call(resource, "POST", payload)
			 ├─ Protocol::HTTP::Request["POST", nil]
			 ├─ prepare_request(request, payload)        ← encode payload, set accept
			 ├─ response_for(resource, request)          ← retry on 429
			 │    └─ resource.call(request)
			 │         ├─ request.path = reference.with(path: request.path)
			 │         ├─ request.headers = resource.headers.merge(request.headers)
			 │         └─ delegate.call(request)         ← AcceptEncoding → HTTP::Client
			 ├─ process_response(request, response)
			 │    └─ wrap_response(response)             ← response.body = parser_for(...).new(body)
			 └─ yield response
						└─ Representation.for(resource, response, &block)
								 └─ new(resource, value: response.read, metadata: response.headers)
```

`response.read` is what invokes `Parser#join`, so a parser that raises on an error envelope
raises at that point — inside the representation's construction or inside `#value`.
