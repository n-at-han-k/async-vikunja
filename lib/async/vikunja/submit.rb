require_relative "error"

module Async
  module Vikunja
    module Submit
      TOO_MANY_REQUESTS = 429

      MAXIMUM_ATTEMPTS = 4

      MAXIMUM_DELAY = 30.0

      def submit(klass, resource, payload = nil, method: :post, through: nil, identify: nil)
        carrier = through || klass

        self.with_retry do
          carrier.public_send(method, resource, payload) do |target, response|
            if response.success?
              self.representation_of(klass, target, response, identify)
            else
              raise Failure.for(response)
            end
          end
        end
      end

      def representation_of(klass, resource, response, identify)
        value = response.read

        klass.new(self.identified(resource, identify, value), value: value, metadata: response.headers)
      end

      def identified(resource, identify, value)
        if identify.nil? || !value.is_a?(Hash) || value[:id].nil?
          resource
        else
          resource.with(path: self.prefix_of(identify) + Vikunja.escape(value[:id]), parameters: nil, merge: false)
        end
      end

      def prefix_of(identify)
        if identify == true
          ""
        else
          identify
        end
      end

      def merge_patch(klass, resource, payload)
        self.submit(klass, resource, payload, method: :patch, through: PatchRepresentation)
      end

      def upload(klass, resource, parts, method: :post)
        self.submit(klass, resource, parts, method: method, through: UploadRepresentation)
      end

      def fetch(klass, resource, payload = nil, method: :post, &block)
        if block
          self.with_retry do
            klass.public_send(method, resource, payload) do |_target, response|
              block.call(response)
            end
          end
        else
          self.submit(klass, resource, payload, method: method)
        end
      end

      def discard(resource, payload = nil, method: :delete)
        self.with_retry do
          Representation.public_send(method, resource, payload) do |target, response|
            if response.success?
              true
            else
              raise Failure.for(response)
            end
          end
        end
      end

      def with_retry(attempts: MAXIMUM_ATTEMPTS, &block)
        attempt = 1

        while true
          begin
            break block.call
          rescue Failure => failure
            if attempt >= attempts
              raise
            end

            unless failure.status == TOO_MANY_REQUESTS
              raise
            end

            delay = failure.retry_after.to_f

            if delay <= 0.0 || delay > MAXIMUM_DELAY
              raise
            end

            attempt += 1

            sleep(delay)
          end
        end
      end
    end
  end
end
