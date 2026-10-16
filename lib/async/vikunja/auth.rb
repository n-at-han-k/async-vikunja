require_relative "page"
require "async/rest/wrapper/form"

module Async
  module Vikunja
    class AuthorizeResponse < Representation
      def code = self.value[:code]

      def redirect_uri = self.value[:redirect_uri]

      def state = self.value[:state]
    end

    class TokenResponse < Representation
      WRAPPER = ::Async::REST::Wrapper::Form.new

      def access_token = self.value[:access_token]

      def expires_in = self.value[:expires_in]

      def refresh_token = self.value[:refresh_token]

      def token_type = self.value[:token_type]
    end

    class AuthToken < Representation
      def self.schema = "AuthTokenBodyBody"

      def token = self.value[:token]
    end

    module Auth
      def login(payload) = self.submit(AuthToken, self.with(path: "login"), payload)

      def logout = self.submit(Representation, self.with(path: "logout"), nil)

      def renew_token = self.submit(AuthToken, self.with(path: "user/token"), nil)

      def refresh_token = self.submit(AuthToken, self.with(path: "user/token/refresh"), nil)

      def confirm_email(payload) = self.submit(Message, self.with(path: "user/confirm"), payload)

      def reset_password(payload) = self.submit(Message, self.with(path: "user/password/reset"), payload)

      def request_password_token(payload) = self.submit(Message, self.with(path: "user/password/token"), payload)

      def oauth_authorize(payload) = self.submit(AuthorizeResponse, self.with(path: "oauth/authorize"), payload)

      def oauth_token(payload) = self.submit(TokenResponse, self.with(path: "oauth/token"), payload)
    end
  end
end
