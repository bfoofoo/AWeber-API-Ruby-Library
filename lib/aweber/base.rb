module AWeber
  class Base

    def initialize(oauth)
      @oauth = oauth
    end

    def account
      accounts.first.last
    end
    
    def get(uri)
      response = oauth.get(expand(uri))
      handle_errors(response, uri)
      parse(response) if response
    end
    
    def delete(uri)
      oauth.delete(expand(uri))
    end
    
    def post(uri, body={})
      oauth.post(expand(uri), body)
    end
    
    def put(uri, body={})
      oauth.put(uri, body.to_json, {"Content-Type" => "application/json"})
    end

    def patch(uri, body={})
      oauth.patch(uri, body.to_json, {"Content-Type" => "application/json"})
    end
    
    def path
      ""
    end
    
    def inspect
      "#<AWeber::Base />"
    end

    # Authorize an app with an auth code from 1.0/oauth/authorize_app/app_id
    #
    # @param [string] auth_code The authorization code received from 
    # /authorize_app to be used for authorization.
    #
    def self.authorize_with_authorization_code(auth_code)
      consumer_token, consumer_secret, request_token, request_secret, verifier =
          auth_code.split('|')
      oauth = AWeber::OAuth.new(consumer_token, consumer_secret)

      request_hash = {:oauth_token => request_token, :oauth_token_secret => request_secret}
      request = ::OAuth::RequestToken.from_hash(oauth.consumer, request_hash)

      oauth.request_token = request
      oauth.authorize_with_verifier(verifier)
      self.new(oauth)
    end

  private
    
    def handle_errors(response, uri)
      if response.is_a? Net::HTTPNotFound
        raise NotFoundError, "Invalid resource uri.", caller
      elsif response && response.body == "NotAuthorizedError"
        raise OAuthError, "Could not authorize OAuth credentials.", caller
      elsif response.is_a? Net::HTTPForbidden
          if JSON.parse(response.body)['error']['message'].start_with?("Rate limit")
              raise RateLimitError, "Too many API requests per minute.", caller
          elsif JSON.parse(response.body)['error']['message'].start_with?("Method requires access")
              raise ForbiddenRequestError, "Method requires extended permissions.", caller
          end
      end
    end

    def accounts
      return @accounts if @accounts

      response  = get("/accounts").merge(:parent => self)
      @accounts = Collection.new(self, Resources::Account, response)
    end

    def expand(uri)
      parsed = URI.parse(uri)
      url = []
      url << AWeber.api_endpoint
      url << API_VERSION unless parsed.path.include? API_VERSION
      url = [url.join("/"), parsed.path].join
      url = [url, parsed.query].join("?") if parsed.query
      url
    end

    def parse(response)
      JSON.parse(response.body)
    end

    def oauth
      @oauth
    end
  end
end
