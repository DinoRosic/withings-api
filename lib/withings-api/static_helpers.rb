require 'oauth'

module Withings
  module Api
    # Simple API to ease the OAuth setup steps for Withing API client apps.
    #
    # Specifically, this class provides methods for OAuth access token creation.
    #
    # 1. Request request tokens - via {#create_request_token}
    # 1. Redirect to authorization URL (this is handled outside of these methods, ie: by the webapp, etc.)
    # 1. Request access tokens (for permanent access to Withings content) - via {#create_access_token}
    module StaticHelpers
      Defaults = Withings::Api::Defaults

      # Issues the "request_token" oauth HTTP request to Withings.
      #
      # For call details @ Withings, see http://www.withings.com/en/api/oauthguide#access
      #
      # For details about registering your application with Withings, see http://www.withings.com/en/api/oauthguide#registration
      #
      # @param [String] consumer_token the consumer key Withings assigned on app registration
      # @param [String] consumer_secret the consumer secret Withings assigned on app registration
      # @param [String] callback_url the URL Withings should return the user to after authorization
      #
      # @return [RequestTokenResponse] something encapsulating the request response
      #
      # @raise [Timeout::Error] on connection, or read timeout
      # @raise [SystemCallError] on low level system call errors (connection timeout, connection refused)
      # @raise [ProtocolError] for HTTP 5XX error response codes
      # @raise [OAuth::Unauthorized] for HTTP 4XX error reponse codes
      # @raise [StandardError] for everything else
      def create_request_token(consumer_token, *arguments)
        _consumer_token, _consumer_secret, _callback_url = nil

        if arguments.length == 1 && consumer_token.instance_of?(Withings::Api::ConsumerToken)
          _consumer_token, _consumer_secret = consumer_token.to_a
        elsif arguments.length == 2
          _consumer_token = consumer_token
          _consumer_secret = arguments.shift
        else
          raise(ArgumentError)
        end
        _callback_url = arguments.shift

        # TODO: warn if the callback URL isn't HTTPS
        consumer = create_consumer(_consumer_token, _consumer_secret)
        oauth_request_token = consumer.get_request_token({:oauth_callback => _callback_url})

        RequestTokenResponse.new oauth_request_token
      end


      # Issues the "access_token" oauth HTTP request to Withings
      #
      # @param [RequestTokenResponse] request_token request token returned from {#create_request_token}
      # @param [String] user_id user id as returned from Withings via the {RequestTokenResponse#authorization_url}
      #
      # @return [] the shit
      def create_access_token(request_token, user_id)
        oauth_request_token = request_token.oauth_request_token

        oauth_access_token = oauth_request_token.get_access_token({:access_token_path => oauth_request_token.consumer.access_token_path})

        # test for unauthorized token, since oauth + withings doesn't turn this into an explicit
        # error code / exception
        if oauth_access_token.params.key?(:"unauthorized token")
          raise StandardError, :"unauthorized token"
        end

        oauth_access_token
      end

      private

      def create_consumer(consumer_key, consumer_secret)
        OAuth::Consumer.new(consumer_key, consumer_secret, {
            :site => Defaults::OAUTH_BASE_URL,
            :scheme        => :query_string,
            :http_method   => :get,
            :signature_method   => 'HMAC-SHA1',
            :request_token_path => Defaults::OAUTH_REQUEST_TOKEN_PATH,
            :authorize_path     => Defaults::OAUTH_AUTHORIZE_PATH,
            :access_token_path  => Defaults::OAUTH_ACCESS_TOKEN_PATH,
        })
      end
    end

    # Simple wrapper class that encapsulates the results of a call to {StaticHelpers#create_request_token}
    class RequestTokenResponse
      def initialize(oauth_request_token)
        self.oauth_request_token = oauth_request_token
      end

      # @return [String] the OAuth request token key
      def token
        self.oauth_request_token.token
      end

      alias :key :token

      # @return [String] the OAuth request token secret
      def secret
        self.oauth_request_token.secret
      end

      # @return [String] URL to redirect the user to to authorize the access to their data
      def authorization_url
        self.oauth_request_token.authorize_url
      end

      attr_accessor :oauth_request_token
    end
  end
end
