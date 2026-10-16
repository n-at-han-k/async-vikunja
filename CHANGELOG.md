# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-16

### Added

- `Async::Vikunja::Client`, an `Async::REST::Resource` for the Vikunja v2 API.
  `Client.open(url)` takes the API root, falling back to `VIKUNJA_URL` and then
  to `http://localhost:3456/api/v2/`. `#authenticated(token)` returns a client
  carrying the bearer credential; every request sends a `user-agent` naming the
  gem and its version.
- Every one of the 193 operations the OpenAPI document describes, reachable from
  the client: projects, tasks, labels, assignees, comments, attachments, views
  and buckets, time entries, teams, link shares and project members, saved
  filters, notifications, reactions, subscriptions, webhooks, API and CalDAV
  tokens, user settings and TOTP, sessions, bots, migration, and the admin
  endpoints.
- `Async::Vikunja::Representation`, the base for every response. Each class
  reads the properties its schema describes and nothing else; a `$ref` arrives
  as the representation the document references, so `project.owner.username` and
  `task.labels.map(&:title)` work without a second request. `#deconstruct_keys`
  and `#deconstruct` make a representation matchable with `case`/`in`, and
  `#cacheable?` reports whether the response may be held on to.
- `Async::Vikunja::Page` and `Async::Vikunja::Collection` for paginated
  collections. A collection is `Enumerable` — `#each` walks every page, while
  `#each_page(per_page:)` hands over each `Page`, which exposes `#items`,
  `#page`, `#per_page`, `#total`, `#total_pages` and `#last?`. Members come back
  addressed at their own published identifier, so `vikunja.projects.first.delete`
  acts on that project rather than on the collection.
- `Async::Vikunja::Download` for the endpoints that answer with bytes rather
  than JSON — attachments, avatars, project backgrounds, TOTP QR codes and the
  notifications feed. `#bytes` is the body and `#media_type` the content type.
- `Async::Vikunja::Failure`, raised for any unsuccessful response, with
  `#status`, `#code`, `#title`, `#detail`, `#errors` and `#retry_after` read off
  the problem document. It descends from `Async::Vikunja::Error`, which is the
  class to rescue for anything this gem raises.
- Rate-limit handling in `Async::Vikunja::Submit`: a `429` with a usable
  `retry-after` is retried, up to 4 attempts and a 30 second ceiling per wait.
  Anything else, including a `retry-after` beyond the ceiling, is raised.
- `#patch` on the resources that support it, sending
  `application/merge-patch+json` through `Async::Vikunja::MergePatch`, alongside
  `#update` for a whole-object `PUT`.
- Uploads through `Async::Vikunja::Multipart` — `#upload_attachments`,
  `#upload_background` and `#upload_avatar` take parts of `{name:, filename:,
  content_type:, body:}`.
- `Async::Vikunja::Redacted`, which masks credentials in `#inspect`: a token,
  password, passcode or secret prints as `[redacted]`. `#value` is untouched, so
  `token.value[:token]` still reads the credential.
- `Async::Vikunja::VERSION`.
- Requires Ruby 3.3 or later, and `async-rest` ~> 0.20.

[Unreleased]: https://github.com/n-at-han-k/async-vikunja/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/n-at-han-k/async-vikunja/releases/tag/v1.0.0
