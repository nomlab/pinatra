# coding: utf-8
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'launchy'
require 'yaml'
require 'json'
require 'net/https'
require 'uri'
require 'pp'

# Retry if rate-limit.
Google::Apis::RequestOptions.default.retries = 5

module Pinatra
  # See: https://developers.google.com/google-apps/calendar/v3/reference/?hl=ja

  CONFIG_PATH = "#{ENV['HOME']}/.config/pinatra/config.yml"

  class GooglePhotoClient
    # see
    # https://github.com/google/google-api-ruby-client#example-usage
    # http://stackoverflow.com/questions/12572723/rails-google-client-api-unable-to-exchange-a-refresh-token-for-access-token

    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
    attr_reader :client

    def initialize(shell = nil)
      config = YAML.load_file(CONFIG_PATH)

      user_id = config["default_user"]
      scope = "https://www.googleapis.com/auth/photoslibrary"

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
  end # class GooglePhotoClient

  class Client
    def initialize(options = {})
      @user_id = options[:user_id]
      @credentials = options[:credentials]
    end

    # album_id で指定されたアルバムから最新の page_size 枚を取得
    def get_albumphotos(album_id, page_size = 100)
      url = "https://photoslibrary.googleapis.com/v1/mediaItems:search"
      uri = URI.parse(url)
      header =  { "Authorization" => "Bearer #{@credentials.access_token}", "Content-Type" => "application/json" }
      request = { "albumId": album_id, "pageSize": page_size }

      begin
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.post(uri.request_uri, request.to_json, header)
        end
        if res.class == Net::HTTPOK
          return JSON.parse(res.body)
        else
          raise "HTTPRequestFailed"
        end
      rescue
        @credentials.refresh!
        header["Authorization"] = "Bearer #{@credentials.access_token}"
        retry
      end
    end

# mediaItemsID で指定された画像を get
    def get_photo(mediaitem_id)
      url = "https://photoslibrary.googleapis.com/v1/mediaItems/#{mediaitem_id}"
      uri = URI.parse(url)
      header =  { "Authorization" => "Bearer #{@credentials.access_token}", "Content-Type" => "application/json" }
      begin
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.get(uri.request_uri, header)
        end
        if res.class == Net::HTTPOK
          return JSON.parse(res.body)
        else
          return nil
        end
      rescue
        @credentials.refresh!
        header["Authorization"] = "Bearer #{@credentials.access_token}"
        retry
      end
    end
  end
end # module Pinatra
