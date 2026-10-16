# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require "async/firefly/server_context"

describe Async::Firefly::Client do
	include Async::Firefly::ServerContext

	with "#about" do
		it "requests the versioned path and authenticates" do
			respond("GET", "/api/v1/about", body: {data: {version: "6.1.0", api_version: "2.0.0"}})

			expect(firefly.about.version).to be == "6.1.0"

			expect(requests.first).to have_keys(
				method: be == "GET",
				path: be == "/api/v1/about",
			)

			expect(requests.first[:headers]["authorization"]).to be == "Bearer test-token"
			expect(requests.first[:headers]["user-agent"]).to be(:include?, "async-firefly")
		end
	end

	with "a failing response" do
		it "raises with the status from the control data" do
			respond("GET", "/api/v1/about", status: 500, body: {message: "broken"})

			expect do
				firefly.about.version
			end.to raise_exception(Async::REST::ResponseError)
		end
	end

	with "#create_transaction" do
		it "sends the split and returns the transaction" do
			respond("POST", "/api/v1/transactions", body: {data: {id: "42", attributes: {group_title: "groceries"}}})

			transaction = firefly.create_transaction({amount: "1.23", description: "milk"})

			expect(transaction.id).to be == "42"
			expect(transaction.group_title).to be == "groceries"

			payload = ::JSON.parse(requests.last[:payload], symbolize_names: true)

			expect(payload).to have_keys(
				error_if_duplicate_hash: be == true,
				transactions: be == [{amount: "1.23", description: "milk"}],
			)
		end

		it "raises Duplicate when the server reports one" do
			respond("POST", "/api/v1/transactions", status: 422,
				body: {message: "Duplicate of transaction #17."})

			expect do
				firefly.create_transaction({amount: "1.23"})
			end.to raise_exception(Async::Firefly::Duplicate)
		end

		it "raises Failure for any other rejection" do
			respond("POST", "/api/v1/transactions", status: 422, body: {message: "amount is required"})

			expect do
				firefly.create_transaction({})
			end.to raise_exception(Async::Firefly::Failure)
		end
	end
end
