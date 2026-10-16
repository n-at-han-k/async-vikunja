require "async/vikunja"
require "async/vikunja/openapi"
require "async/vikunja/representation_context"

Async::Vikunja::Representation.subclasses.sort_by(&:name).each do |klass|
  if Async::Vikunja::OpenAPI.schema_for(klass.schema)
    describe klass do
      it_behaves_like Async::Vikunja::RepresentationContext
    end
  end
end
