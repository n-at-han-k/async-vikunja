# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require "async/rest/resource"

require_relative "about"
require_relative "accounts"
require_relative "error"
require_relative "transactions"
require_relative "version"

module Async
	module Firefly
		class Client < Async::REST::Resource
			ENDPOINT = Async::HTTP::Endpoint.parse(ENV.fetch("FIREFLY_URL", "http://localhost:8080/api/v1/"))

			USER_AGENT = "async-firefly (https://github.com/you/async-firefly, v#{VERSION})"

			TOO_MANY_REQUESTS = 429
			UNPROCESSABLE = 422

			MAXIMUM_ATTEMPTS = 4
			MAXIMUM_DELAY = 30.0

			DUPLICATE = "Duplicate of transaction"

			def initialize(delegate, reference = ::Protocol::URL::Reference.parse, headers = ::Protocol::HTTP::Headers.new)
				super

				unless @headers["user-agent"]
					@headers = @headers.merge("user-agent" => USER_AGENT)
				end
			end

			def authenticated(token)
				self.with(headers: {"authorization" => "Bearer #{token}"})
			end

			def about
				About.new(self.with(path: "about"))
			end

			def accounts(type: "asset")
				Accounts.for(self, type: type)
			end

			def account(id)
				Account.new(self.with(path: "accounts/#{::Protocol::URL::Encoding.escape(id.to_s)}"))
			end

			def transaction(id)
				Transaction.new(self.with(path: "transactions/#{::Protocol::URL::Encoding.escape(id.to_s)}"))
			end

			def transactions(**parameters)
				Transactions.for(self, **parameters)
			end

			def search_transactions(query, limit: 10)
				TransactionPage.new(self.with(path: "search/transactions", parameters: {query: query, limit: limit}))
			end

			def find_by_external_id(external_id)
				self.search_transactions(%(external_id:"#{external_id}")).first
			end

			def create_account(name:, role: "defaultAsset", currency_code: "GBP", **attributes)
				payload = {
					name: name,
					type: "asset",
					account_role: role,
					currency_code: currency_code,
					include_net_worth: true,
					**attributes,
				}

				self.with_retry do
					self.submit(Account, self.with(path: "accounts"), payload)
				end
			end

			def create_transaction(split, group_title: nil, apply_rules: true)
				payload = {
					error_if_duplicate_hash: true,
					apply_rules: apply_rules,
					fire_webhooks: true,
					group_title: group_title,
					transactions: [split],
				}

				self.with_retry do
					self.submit(Transaction, self.with(path: "transactions"), payload)
				end
			end

			def update_transaction(id, split, apply_rules: false)
				payload = {
					apply_rules: apply_rules,
					fire_webhooks: false,
					transactions: [split],
				}

				resource = self.with(path: "transactions/#{::Protocol::URL::Encoding.escape(id.to_s)}")

				self.with_retry do
					self.submit(Transaction, resource, payload, method: :put)
				end
			end

			private

			def submit(klass, resource, payload, method: :post)
				klass.public_send(method, resource, payload) do |resource, response|
					if response.success?
						klass.new(resource, value: response.read, metadata: response.headers)
					else
						raise self.failure_for(response)
					end
				end
			end

			def failure_for(response)
				status = response.status
				payload = response.read
				message = "#{status}: #{payload.inspect}"

				if status == UNPROCESSABLE and payload.to_s.include?(DUPLICATE)
					Duplicate.new(message, status: status, payload: payload)
				else
					Failure.new(message, status: status, payload: payload)
				end
			end

			def with_retry(attempts: MAXIMUM_ATTEMPTS)
				attempt = 0

				while true
					attempt += 1

					begin
						return yield
					rescue Failure => failure
						raise if attempt >= attempts
						raise unless failure.status == TOO_MANY_REQUESTS

						delay = failure.payload.to_s[/\d+/]&.to_f || 1.0
						raise if delay > MAXIMUM_DELAY

						sleep(delay)
					end
				end
			end
		end
	end
end
