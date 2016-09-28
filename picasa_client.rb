require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'picasa'
require 'launchy'
require 'yaml'
require 'pp'

# Retry if rate-limit.
Google::Apis::RequestOptions.default.retries = 5

module Pinatra
  # See: https://developers.google.com/google-apps/calendar/v3/reference/?hl=ja

  CONFIG_PATH = "#{ENV['HOME']}/.config/pinatra/config.yml"

  class PicasaClient
    # see
    # https://github.com/google/google-api-ruby-client#example-usage
    # http://stackoverflow.com/questions/12572723/rails-google-client-api-unable-to-exchange-a-refresh-token-for-access-token

    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
    attr_reader :client

    def initialize(shell = nil)
      config = YAML.load_file(CONFIG_PATH)

      user_id = config["default_user"]
      # scope = Google::Apis::GmailV1::AUTH_GMAIL_LABELS
      scope = "https://picasaweb.google.com/data/"

      client_id = Google::Auth::ClientId.new(
        config["client_id"],
        config["client_secret"]
      )
      token_store = Google::Auth::Stores::FileTokenStore.new(
        :file => config["token_store"]
      )
      authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
      credentials = authorizer.get_credentials(user_id)
      if credentials.nil?
        unless shell
          puts "Please run tokengetter.rb"
          exit
        end
        url = authorizer.get_authorization_url(base_url: OOB_URI)

        begin
          Launchy.open(url)
        rescue
          puts "Open URL in your browser:\n  #{url}"
        end
        code = shell.ask "Enter the resulting code:"
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: OOB_URI
        )
      end
      credentials.refresh! if credentials.refresh_token && credentials.expired?

      @client = Pinatra::Client.new(user_id: user_id, credentials: credentials)
      return @client
    end
  end # class Calendar

  class Client
    def initialize(options = {})
      @user_id = options[:user_id]
      @credentials = options[:credentials]
      @client = Picasa::Client.new(user_id: @user_id, access_token: @credentials.access_token)
    end

    def api(api_class, api_method, args, options = {})
      if @client.respond_to?(api_class) &&
         @client.send(api_class).respond_to?(api_method)
        begin
          return @client.send(api_class).send(api_method, *args, options)
        rescue Picasa::ForbiddenError
          @credentials.refresh!
          @client = Picasa::Client.new(user_id: @user_id, access_token: @credentials.access_token)
          retry
        end
      end
    end
  end
end # module Glima
