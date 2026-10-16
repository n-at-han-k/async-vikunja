# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

require_relative "representation"

module Async
	module Firefly
		class Account < Representation
			def id
				self.data[:id]
			end

			def name
				self.attributes[:name]
			end

			def currency_code
				self.attributes[:currency_code]
			end

			def current_balance
				self.attributes[:current_balance]
			end
		end

		class AccountPage < Representation
			include Enumerable

			def each
				return to_enum unless block_given?

				Array(self.data).each do |record|
					resource = @resource.with(path: "../accounts/#{::Protocol::URL::Encoding.escape(record[:id].to_s)}", parameters: nil, merge: false)

					yield Account.new(resource, value: {data: record}, metadata: self.metadata)
				end
			end

			def total_pages
				self.value.dig(:meta, :pagination, :total_pages).to_i
			end

			def current_page
				self.value.dig(:meta, :pagination, :current_page).to_i
			end

			def last?
				self.current_page >= [self.total_pages, 1].max
			end
		end

		class Accounts
			include Enumerable

			DEFAULT_LIMIT = 100

			def self.for(parent, **parameters)
				self.new(parent.with(path: "accounts", parameters: parameters))
			end

			def initialize(resource)
				@resource = resource
			end

			def each_page(limit: DEFAULT_LIMIT)
				return to_enum(:each_page, limit: limit) unless block_given?

				page = 1

				while true
					accounts = AccountPage.new(@resource.with(parameters: {page: page, limit: limit}))

					break if Array(accounts.data).empty?

					yield accounts

					break if accounts.last?

					page += 1
				end
			end

			def each(**options, &block)
				return to_enum(:each, **options) unless block_given?

				self.each_page(**options){|accounts| accounts.each(&block)}
			end
		end
	end
end
