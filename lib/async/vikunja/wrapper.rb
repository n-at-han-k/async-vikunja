require "async/rest/wrapper/json"
require "protocol/http/body/buffered"
require "protocol/http/body/file"
require "protocol/http/body/readable"

require_relative "error"

module Async
  module Vikunja
    class Wrapper < Async::REST::Wrapper::JSON
      JSON_SUFFIX = "json"

      def response_for(resource, request) = resource.call(request)

      def parser_for(response)
        content_type = response.headers["content-type"]

        if content_type&.include?(JSON_SUFFIX)
          Async::REST::Wrapper::JSON::Parser
        end
      end
    end

    class MergePatch < Wrapper
      MERGE_PATCH_JSON = "application/merge-patch+json"

      def prepare_request(request, payload)
        request.headers["accept"] ||= self.content_type

        if payload
          request.headers["content-type"] = MERGE_PATCH_JSON
          request.body = ::Protocol::HTTP::Body::Buffered.new([::JSON.dump(payload)])
        end
      end
    end

    class Transfer < Wrapper
      ANY = "*/*"

      def prepare_request(request, payload)
        request.headers["accept"] ||= ANY

        if payload
          request.headers["content-type"] = self.content_type
          request.body = ::Protocol::HTTP::Body::Buffered.new([::JSON.dump(payload)])
        end
      end

      def process_response(request, response)
        super

        unless response.success?
          raise Failure.for(response)
        end

        response
      end
    end

    class Multipart < Wrapper
      MULTIPART_FORM_DATA = "multipart/form-data"

      BOUNDARY = "async-vikunja-boundary"

      OCTET_STREAM = "application/octet-stream"

      CRLF = "\r\n"

      class Body < ::Protocol::HTTP::Body::Readable
        def initialize(bodies)
          @bodies = bodies
          @index = 0
        end

        def length
          lengths = @bodies.map(&:length)

          if lengths.include?(nil)
            nil
          else
            lengths.sum
          end
        end

        def empty? = @index >= @bodies.size

        def ready? = true

        def read
          chunk = nil

          while chunk.nil? && @index < @bodies.size
            chunk = @bodies[@index].read

            if chunk.nil?
              @index += 1
            end
          end

          chunk
        end

        def close(error = nil)
          @bodies.each do |body|
            body.close(error)
          end

          @index = @bodies.size

          super
        end
      end

      def prepare_request(request, payload)
        request.headers["accept"] ||= self.content_type

        if payload
          request.headers["content-type"] = MULTIPART_FORM_DATA + "; boundary=" + BOUNDARY
          request.body = Body.new(self.bodies_for(payload))
        end
      end

      def bodies_for(parts)
        [].tap do |bodies|
          Array(parts).each do |part|
            bodies << self.buffered(self.preamble_of(part))
            bodies << self.body_of(part)
            bodies << self.buffered(CRLF)
          end

          bodies << self.buffered("--" + BOUNDARY + "--" + CRLF)
        end
      end

      def buffered(text) = ::Protocol::HTTP::Body::Buffered.new([self.binary(text)])

      def binary(text)
        case text.encoding
        when ::Encoding::BINARY
          text
        else
          text.b
        end
      end

      def body_of(part)
        body = part.fetch(:body)

        case body
        when ::Protocol::HTTP::Body::Readable
          body
        when ::IO, ::StringIO
          ::Protocol::HTTP::Body::File.new(body)
        else
          self.buffered(body.to_s)
        end
      end

      def preamble_of(part)
        "--" + BOUNDARY + CRLF +
          "content-disposition: form-data; " + self.disposition_of(part) + CRLF +
          "content-type: " + (part[:content_type] || OCTET_STREAM) + CRLF +
          CRLF
      end

      def disposition_of(part)
        ("name=" + part.fetch(:name).to_s.inspect).tap do |disposition|
          if part[:filename]
            disposition << "; filename=" + part[:filename].to_s.inspect
          end
        end
      end
    end
  end
end
