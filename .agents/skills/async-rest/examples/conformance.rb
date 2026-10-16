#!/usr/bin/env ruby

require "async"
require "async/http/server"
require "async/http/endpoint"

require_relative "chat"

MESSAGES = [
	{id: 5, content: "third"},
	{id: 4, content: "second"},
	{id: 3, content: "first"},
]

REQUESTS = []

def page_for(anchor, limit)
	available = anchor == "newest" ? MESSAGES : MESSAGES.select{|m| m[:id] <= anchor.to_i}
	taken = available.first(limit)

	{messages: taken, found_oldest: taken.last == MESSAGES.last}
end

app = ::Protocol::HTTP::Middleware.for do |request|
	path, query = request.path.split("?", 2)
	REQUESTS << {method: request.method, path: path, query: query, authorization: request.headers["authorization"]}

	case [request.method, path]
	in ["GET", "/api/v1/rooms/general/messages"]
		parameters = ::Protocol::URL::Encoding.decode(query.to_s, symbolize_keys: true)
		body = page_for(parameters[:anchor], parameters[:num_before].to_i)

		::Protocol::HTTP::Response[200, {"content-type" => "application/json", "cache-control" => "no-store"}, [::JSON.dump(body)]]
	in ["POST", "/api/v1/messages"]
		if REQUESTS.count{|r| r[:path] == "/api/v1/messages"} < 3
			::Protocol::HTTP::Response[429, {"content-type" => "application/json", "retry-after" => "0"}, ['{"error":"slow down"}']]
		else
			::Protocol::HTTP::Response[200, {"content-type" => "application/json"}, ['{"id":9,"access_token":"supersecret"}']]
		end
	in ["GET", "/api/v1/rooms/missing/messages"]
		::Protocol::HTTP::Response[404, {"content-type" => "application/json"}, ['{"error":"no_such_room"}']]
	else
		::Protocol::HTTP::Response[404, {}, []]
	end
end

endpoint = Async::HTTP::Endpoint.parse("http://localhost:9500")

Async do
	server = Async{Async::HTTP::Server.new(app, endpoint).run}
	sleep 0.5

	Async::Chat::Client.open("http://localhost:9500") do |client|
		client = client.authenticated("a@b.com", "key")

		REQUESTS.clear
		puts "rule 26 - every message, one page at a time:"
		puts "  #{client.room("general").messages.map(&:content).inspect}  (#{REQUESTS.size} requests)"

		REQUESTS.clear
		puts "rule 26 - take(2) stops after the first page:"
		puts "  #{client.room("general").messages.take(2).map(&:content).inspect}  (#{REQUESTS.size} request)"

		puts "rule 26 - each page carries its own metadata:"
		client.room("general").messages.each_page do |page|
			puts "  #{page.value[:messages].size} items  cacheable?=#{page.cacheable?}"
		end

		REQUESTS.clear
		puts "rules 20, 21 - retry builds a new request each attempt:"
		sent = client.send_message(to: "general", content: "hello")
		puts "  id=#{sent.id} after #{REQUESTS.size} attempts"
		REQUESTS.each{|r| puts "    #{r[:method]} #{r[:path]}#{r[:query] ? "?#{r[:query]}" : ""}"}

		puts "rule 25 - the token is masked in inspect:"
		puts "  #{sent.inspect}"

		puts "rule 22 - the kind of representation is discriminated:"
		result =
			case sent
			in {id: Integer => id} then "sent id=#{id}"
			in {error: String => message} then "failed: #{message}"
			end
		puts "  #{result}"

		puts "rule 18 - the failure is read from the control data:"
		begin
			client.room("missing").messages.first
		rescue Async::REST::ResponseError => error
			puts "  status=#{error.response.status}"
		end

		puts "rule 13 - every request declared what it accepts:"
		puts "  authorization sent on every request? #{REQUESTS.all?{|r| r[:authorization]}}"
	end

	server.stop
end
