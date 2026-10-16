# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require "async/firefly/server_context"

describe Async::Firefly::Accounts do
	include Async::Firefly::ServerContext

	def respond_pages
		respond("GET", "/api/v1/accounts", body: {
			data: [
				{id: "1", attributes: {name: "Current", currency_code: "GBP"}},
				{id: "2", attributes: {name: "Savings", currency_code: "GBP"}},
			],
			meta: {pagination: {current_page: 1, total_pages: 1}},
		})
	end

	it "yields an account representation per record" do
		respond_pages

		accounts = firefly.accounts.to_a

		expect(accounts.size).to be == 2
		expect(accounts.first).to be_a(Async::Firefly::Account)
		expect(accounts.first.name).to be == "Current"
	end

	it "seeds each account so listing costs one request" do
		respond_pages

		firefly.accounts.map(&:name)

		expect(requests.size).to be == 1
	end

	it "sends the type and the page parameters" do
		respond_pages

		firefly.accounts(type: "expense").to_a

		expect(requests.first[:query]).to have_keys(
			type: be == "expense",
			page: be == "1",
			limit: be == "100",
		)
	end

	with "a page of its own" do
		it "carries the metadata describing its own response" do
			respond_pages

			page = firefly.accounts.each_page.first

			expect(page).to be_a(Async::Firefly::AccountPage)
			expect(page.total_pages).to be == 1
			expect(page.metadata["content-type"]).to be == "application/vnd.api+json"
		end
	end
end
