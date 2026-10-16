---
name: async-rest-client
description: Build a Ruby client library for any HTTP/JSON API on top of the async-rest gem, modelling the API as Resource, Representation and Wrapper subclasses. Use this skill whenever the user wants a Ruby API client, wrapper, SDK or binding for some web service built on async-rest or the socketry Async ecosystem; whenever they mention async-rest, Async::REST, Async::HTTP::Endpoint, or a non-blocking/fibre-based Ruby HTTP client; and whenever they want to add endpoints, authentication, pagination, streaming or error handling to an existing async-rest client. Applies even if the user never names the gem — "write me a Ruby client for the Stripe API using async" is exactly this skill. The async-rest API has traps that make from-memory code unreliable; always consult this skill first.
---

# Async::REST Client

House rules for `async-rest` clients. Every rule was derived by reading the library source and
running it against a live server.

**Where this document and your recollection of `async-rest` disagree, this document wins.**
Several rules contradict what the code looks like it does: a class-level verb does not check
the response status, the built-in retry corrupts the request it replays, and
`Resource.open(url, headers: …)` silently discards the headers. Reasoning from what the API
ought to do produces all three mistakes.

All code produced or reviewed must conform. Cite rule numbers when reviewing.

## The rules

| Document | Rules | Covers |
|---|---|---|
| `rules/definitions.md` | 1–10 | The axioms: what a resource, a representation and data each are. Everything else depends on these. **Closed — no further axioms.** |
| `rules/architecture.md` | 11, 13–17, 22, 26, 27 | Conformance: what REST requires of a client. Breaking one produces a non-conforming client. |
| `rules/errors.md` | 18–21, 23 | Error handling and retry, and the library's three raise sites. |
| `rules/auth.md` | 28 | Carrying a credential. One rule per technique; a client uses the one its API specifies. |
| `rules/style.md` | 12, 24, 25, 29 | Where the architecture permits more than one arrangement. Breaking one produces a conforming client that is harder to reason about. |

Read `rules/definitions.md` first. Read the rest when the task touches them.

## Example

`examples/chat.rb` is a complete client conforming to all 26 rules.
`examples/conformance.rb` runs it against an in-process server and reports what each rule
produced on the wire, which is how rule 11 says conformance is established:

```bash
ruby examples/conformance.rb
```

## Sources

Nothing is vendored here. The authorities are read from where they live:

- **Fielding's dissertation**, *Architectural Styles and the Design of Network-based Software
  Architectures* — <https://ics.uci.edu/~fielding/pubs/dissertation/top.htm>. Rules cite it by
  section (`§5.2.1.2`), which is stable across copies. Chapter 5 is `rest_arch_style.htm`,
  Chapter 1 `software_arch.htm`, Chapter 2 `net_app_arch.htm`, Chapter 6 `evaluation.htm`.
- **The library** — `async-rest` is about 450 lines. Read `lib/async/rest/*.rb` in the
  installed gem. It is the final word over any description, including this skill's.
- **Client gems** — `async-ollama` and `async-discord` track the current API. See the table
  below before copying from any of them.

## What not to copy from the ecosystem

The published clients are not uniformly current. Four practices appear in shipped code and must
not be reproduced.

| Practice | Where | Why not |
|---|---|---|
| `Client.for` / `Resource.for` as an entry point | `async-slack/lib/async/slack.rb:31`, `async-rest/examples/{github/feed.rb:107,slack/clean.rb:21,xkcd/comic.rb:59}` | `Resource` has no `.for`. The entry point is `.open`. |
| Raising a mapped error from the parser | `async-slack/lib/async/slack/representation.rb:29` | An error body is a representation (§5.2.1.2). `async-ollama` exposes `#error` instead. |
| `do |response|` on a class-level verb's block | `async-rest/examples/ollama/ollama.rb:130` | The block yields `(resource, response, klass)`, so the first parameter binds the resource. |
| Absolute paths that restate `ENDPOINT`'s prefix | `async-discord/lib/async/discord/{guilds.rb:35,channels.rb:57}` | The prefix is already in `ENDPOINT` (`client.rb:16`), so bumping the version leaves these behind. |

`async-slack` is pinned to `async-rest ~> 0.12` and is not a reference for anything; it also
ships a `binding.irb` in library code at `lib/async/slack/search.rb:72`. `cloudflare` predates
the current shape entirely.

## Extending these rules

When a rule fails against a running server, **the rule is wrong, not the server.** Record the
output you actually observed, then correct or delete the rule. Never leave a rule in place that
you have seen fail, and never add a rule you have not executed.

A new rule takes the same form as the existing ones: a number, a name, one bold imperative
sentence, a wrong and a right example each showing the containing class and its usage inside a
`Client.open` block, and a `**Reason:**` citing the dissertation section or the library source.
Nothing is a rule until it is written in that form.

If something is genuinely not covered, that is where judgement belongs. Work it out against a
running server, then write it down.
