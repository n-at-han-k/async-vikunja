require "async/vikunja"

require_relative "openapi"

module Async
  module Vikunja
    RepresentationContext = Sus::Shared("a representation of its schema") do
      let(:schema_name) {subject.schema}

      let(:properties) {OpenAPI.properties_of(schema_name)}

      let(:resource) {Client.new(nil, ::Protocol::URL::Reference.parse("/api/v2/example"))}

      let(:payload) {properties.to_h{|name, property| [name.to_sym, sample_of(name, property)]}}

      let(:representation) {subject.new(resource, value: payload, metadata: {"content-type" => "application/json"})}

      def sample_of(name, property, nested: false)
        kind, reference = OpenAPI.reference_of(property)

        case kind
        when :one
          nested_sample(reference, nested)
        when :many
          [nested_sample(reference, nested)]
        else
          scalar_of(name, property)
        end
      end

      def nested_sample(reference, nested)
        if nested
          {}
        else
          OpenAPI.properties_of(reference).to_h do |name, property|
            [name.to_sym, sample_of(name, property, nested: true)]
          end
        end
      end

      def scalar_of(name, property)
        case Array(property["type"]).reject{|type| type == "null"}.first
        when "integer"
          7
        when "number"
          1.5
        when "boolean"
          true
        when "array"
          []
        when "object"
          {}
        else
          name.to_s + "-example"
        end
      end

      it "describes a schema the API answers with" do
        expect(OpenAPI.schema_for(schema_name)).not.to be_nil
      end

      let(:reserved) {["value", "metadata", "resource"]}

      let(:named) {properties.reject{|name, _| reserved.include?(name)}}

      it "reads every property the schema describes" do
        missing = named.keys.reject{|name| representation.respond_to?(name)}

        expect(missing).to be == []
      end

      it "reads each property out of the value it arrived in" do
        named.each do |name, property|
          kind, _ = OpenAPI.reference_of(property)

          unless kind
            expect(representation.public_send(name)).to be == payload[name.to_sym]
          end
        end
      end

      it "wraps each nested object as the representation the document references" do
        named.each do |name, property|
          kind, reference = OpenAPI.reference_of(property)

          if kind == :one
            nested = representation.public_send(name)

            expect(nested).to be_a(Representation)
            expect(nested.class.name.split("::").last).to be == reference
            expect(nested.value).to be == payload[name.to_sym]
          end
        end
      end

      it "wraps each nested list as the representations the document references" do
        named.each do |name, property|
          kind, reference = OpenAPI.reference_of(property)

          if kind == :many
            nested = representation.public_send(name)

            expect(nested).to be_a(Array)
            expect(nested.size).to be == 1
            expect(nested.first.class.name.split("::").last).to be == reference
          end
        end
      end

      it "reports no value as no value, rather than as something else" do
        empty = subject.new(resource, value: {})

        filled = named.each_key.reject{|name| self.blank?(empty.public_send(name))}

        expect(filled).to be == []
      end

      def blank?(value)
        case value
        when nil
          true
        when Array, Hash, String
          value.empty?
        else
          false
        end
      end

      it "masks a credential when it is inspected" do
        secrets = properties.keys.map(&:to_sym) & Redacted::SECRET

        secrets.each do |name|
          expect(representation.inspect).not.to be(:include?, payload[name].to_s)
        end
      end
    end
  end
end
