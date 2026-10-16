require "async/rest/wrapper/json"
require "protocol/http/body/buffered"

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

    class Multipart < Wrapper
      MULTIPART_FORM_DATA = "multipart/form-data"

      BOUNDARY = "async-vikunja-boundary"

      OCTET_STREAM = "application/octet-stream"

      CRLF = "\r\n"

      def prepare_request(request, payload)
        request.headers["accept"] ||= self.content_type

        if payload
          request.headers["content-type"] = MULTIPART_FORM_DATA + "; boundary=" + BOUNDARY
          request.body = ::Protocol::HTTP::Body::Buffered.new([self.encode(payload)])
        end
      end

      def encode(parts)
        String.new.tap do |encoded|
          Array(parts).each do |part|
            encoded << "--" + BOUNDARY + CRLF
            encoded << "content-disposition: form-data; " + self.disposition_of(part) + CRLF
            encoded << "content-type: " + (part[:content_type] || OCTET_STREAM) + CRLF
            encoded << CRLF
            encoded << part.fetch(:body).to_s
            encoded << CRLF
          end

          encoded << "--" + BOUNDARY + "--" + CRLF
        end
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
