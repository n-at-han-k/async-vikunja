# async-vikunja ruby gem


## Important

* Read the async-rest skill before doing anything
* This project uses nix flakes... every command should be prefixed with `nix develop --command`.

## Testing

```bash
nix develop --command bundle exec sus
docker compose up -d --wait
eval "$(bin/vikunja-bootstrap)"
docker compose down -v
```

Live tests skip unless `VIKUNJA_URL`/`VIKUNJA_TOKEN` are set.

## Rubocop

```bash
nix develop --command bundle exec rubocop --cache false
nix develop --command bundle exec rubocop --cache false -A
```

`--cache false` is required: the entity cop reads `data/openapi-v2.json`, which is not in RuboCop's
cache key.

The cops under `cops/` check the client against the document rather than against taste:

* `EntityHasRepresentation` - every schema an operation answers with has a `class X < Representation`.
  `.rubocop_todo.yml` lists what is not written yet; it is empty.
* `AccessorMatchesSchema` - a representation reads every property of its schema and no key the
  document does not describe. A `*ReadBody` sibling's properties count as the same entity's.
* `AccessorNamesProperty` - an accessor is named after the property it reads.
* `CreateIdentifiesResource` - a `create_*` method says what identifies the resource it created,
  because a creation answers at the collection's address rather than the new resource's.
* `ShadowedConstant` - `Async::Vikunja::File` shadows `::File` inside the namespace, so a bare
  `File.read` there is an error waiting to happen.

`fixtures/async/vikunja/representation_context.rb` is the other half, and it is what the cops
cannot be: a schema-driven shared fixture. It builds a sample payload out of the schema, then
asserts each accessor reads its own property, that a `$ref` arrives as the representation the
document references, that an absent value stays absent, and that a credential is masked.
`test/async/vikunja/representations.rb` enumerates `Representation.subclasses` and applies it, so
coverage follows the classes rather than a list anybody has to maintain. A class named differently
from its schema says so with `def self.schema`.

`test/async/vikunja/conformance.rb` establishes conformance the way rule 11 asks: it walks every
method reachable from the client against a recording server and asserts what went over the wire -
that every request matched a documented route, that all 193 of them are reachable, that each
carries the credential, and that every page derives its members at a published identifier.
