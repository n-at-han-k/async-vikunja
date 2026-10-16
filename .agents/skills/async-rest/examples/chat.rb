#!/usr/bin/env ruby

require "async/rest"

module Async
	module Chat
		V1 = "/api/v1"

		class Error < StandardError
		end

		module Redacted
			SECRET = [:access_token, :refresh_token, :client_secret, :password, :token].freeze
			REDACTED = "[redacted]"

			def self.redact(value)
				case value
				when Hash
					value.to_h{|key, nested| SECRET.include?(key) ? [key, REDACTED] : [key, self.redact(nested)]}
				when Array
					value.map{|each| self.redact(each)}
				else
					value
				end
			end

			def inspect
				"\#<#{self.class} #{@resource.path.to_s.inspect} value=#{Redacted.redact(@value).inspect}>"
			end
		end

		class Wrapper < Async::REST::Wrapper::JSON
			def response_for(resource, request)
				resource.call(request)
			end

			def parser_for(response)
				if content_type = response.headers["content-type"]
					if content_type.start_with?(@content_type)
						return Async::REST::Wrapper::JSON::Parser
					end
				end

				super
			end
		end

		class Representation < Async::REST::Representation[Wrapper]
			include Redacted

			def deconstruct_keys(keys)
				case self.value
				in Hash => value then value
				else {}
				end
			end

			def deconstruct
				case self.value
				in Array => value then value
				else []
				end
			end

			def cacheable?
				if cache_control = self.metadata["cache-control"]
					!cache_control.no_store?
				else
					true
				end
			end
		end

		class Message < Representation
			def id = self.value[:id]
			def content = self.value[:content]
		end

		class Sent < Representation
			def id = self.value[:id]
		end

		class Page < Representation
			include Enumerable

			def each
				return to_enum unless block_given?

				self.value[:messages].each do |attributes|
					resource = @resource.with(path: "../messages/#{::Protocol::URL::Encoding.escape(attributes[:id].to_s)}")

					yield Message.new(resource, value: attributes, metadata: self.metadata)
				end
			end

			def found_oldest? = self.value[:found_oldest]
		end

		class Messages
			include Enumerable

			DEFAULT_LIMIT = 2

			def self.for(parent)
				self.new(parent.with(path: "messages"))
			end

			def initialize(resource)
				@resource = resource
			end

			def each_page(limit: DEFAULT_LIMIT, anchor: "newest")
				return to_enum(:each_page, limit: limit, anchor: anchor) unless block_given?

				while true
					page = Page.new(@resource.with(parameters: {anchor: anchor, num_before: limit}))

					break if page.value[:messages].empty?

					yield page

					break if page.found_oldest?

					anchor = page.value[:messages].last[:id] - 1
				end
			end

			def each(**options, &block)
				return to_enum(:each, **options) unless block_given?

				self.each_page(**options){|page| page.each(&block)}
			end
		end

		class Room
			def self.for(parent, id)
				self.new(parent.with(path: "rooms/#{::Protocol::URL::Encoding.escape(id)}"), id)
			end

			def initialize(resource, id)
				@resource = resource
				@id = id
			end

			attr :id

			def messages
				Messages.for(@resource)
			end
		end

		class Client < Async::REST::Resource
			ENDPOINT = Async::HTTP::Endpoint.parse("https://chat.example.com")

			MAXIMUM_ATTEMPTS = 4
			MAXIMUM_DELAY = 30.0

			def authenticated(email, api_key)
				self.with(headers: {"authorization" => "Basic #{["#{email}:#{api_key}"].pack("m0")}"})
			end

			def room(id)
				Room.for(self.with(path: V1), id)
			end

			def send_message(to:, content:)
				self.with_retry do
					Sent.post(self.with(path: "#{V1}/messages"), {to: to, content: content}) do |resource, response|
						raise Async::REST::ResponseError, response unless response.success?

						Sent.new(resource, value: response.read, metadata: response.headers)
					end
				end
			end

			private def with_retry(attempts: MAXIMUM_ATTEMPTS)
				attempt = 0

				while true
					attempt += 1

					begin
						return yield
					rescue Async::REST::ResponseError => error
						raise if attempt >= attempts
						raise unless error.response.status == 429

						delay = error.response.headers["retry-after"]&.to_f or raise
						raise if delay > MAXIMUM_DELAY

						sleep(delay)
					end
				end
			end
		end
	end
end
