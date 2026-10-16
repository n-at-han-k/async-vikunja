# async-firefly

```ruby
gem "async-firefly"
```

```ruby
require "async/firefly"

Async::Firefly::Client.open("https://firefly.example.com/api/v1/") do |client|
	firefly = client.authenticated(ENV.fetch("FIREFLY_TOKEN"))

	firefly.about.version
	firefly.about.api_version
	firefly.about.os
end
```

```ruby
Async::Firefly::Client.open do |client|
	firefly = client.authenticated(ENV.fetch("FIREFLY_TOKEN"))
end
```

```ruby
firefly.accounts.map(&:name)
firefly.accounts(type: "expense").count
firefly.accounts.take(5).map(&:current_balance)

firefly.accounts.each_page(limit: 25) do |page|
	page.current_page
	page.total_pages
	page.last?
	page.metadata["content-type"]

	page.each{|account| account.name}
end
```

```ruby
account = firefly.create_account(name: "Savings", currency_code: "GBP")

account.id
account.name
account.currency_code
account.current_balance

firefly.account(account.id).name
```

```ruby
firefly.transactions(type: "withdrawal").map(&:group_title)
firefly.transaction(7).splits.map{|split| split[:amount]}
firefly.transaction(7).external_id

firefly.search_transactions("groceries", limit: 25).map(&:group_title)
firefly.find_by_external_id("till-0001")&.id
```

```ruby
transaction = firefly.create_transaction({
	type: "withdrawal",
	date: Time.now.utc.iso8601,
	amount: "12.50",
	description: "Coffee",
	source_id: account.id,
	external_id: "till-0001",
}, group_title: "Tuesday")

transaction.id
transaction.splits.first[:description]

firefly.update_transaction(transaction.id, {
	transaction_journal_id: transaction.splits.first[:transaction_journal_id],
	description: "Coffee and a bun",
})
```

```ruby
case firefly.account(1)
in {data: {id: String => id, attributes: {name: String => name}}}
	[id, name]
end

case firefly.transactions.first
in {data: {attributes: {group_title: String => title}}}
	title
end
```

```ruby
begin
	firefly.create_transaction({type: "withdrawal"})
rescue Async::Firefly::Duplicate => error
	error.status
	error.payload
rescue Async::Firefly::Failure => error
	error.status
	error.payload
end

begin
	firefly.account(404).name
rescue Async::REST::ResponseError => error
	error.response.status
rescue ::JSON::ParserError => error
	error.message
end
```

```ruby
account = firefly.account(1)

account.current_balance
account = firefly.account(1) unless account.cacheable?
account.current_balance
```

```ruby
firefly.account(1).inspect
firefly.account(1).value
```

```ruby
Async::Firefly::Client.open do |client|
	firefly = client.authenticated(ENV.fetch("FIREFLY_TOKEN"))

	balances = firefly.accounts.map do |account|
		Async do
			firefly.account(account.id).current_balance
		end
	end

	balances.map(&:wait)
end
```
