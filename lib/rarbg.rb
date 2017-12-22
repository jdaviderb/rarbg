require 'faraday'
require 'faraday_middleware'
require 'json'
require 'time'

# A ruby wrapper for RARBG torrentapi.
module RARBG
  VERSION = '0.1.4'.freeze
  APP_ID = 'rarbg-rubygem'.freeze
  API_ENDPOINT = 'https://torrentapi.org/pubapi_v2.php'.freeze
  TOKEN_EXPIRATION = 800

  # Exception for low level request errors.
  class RequestError < StandardError; end
  # Exception for high level API errors.
  class APIError < StandardError; end

  # API class for performing requests.
  class API
    # API +token+ is stored with timestamped +token_time+.
    attr_reader   :token, :token_time

    # Any API call passes +default_params+ unless overidden.
    attr_accessor :default_params

    # Returns a new API object with +@default_params+ defined in +params+.
    def initialize(params = {})
      @default_params = {
        'limit'  => 25,
        'sort'   => 'last',
        'format' => 'json_extended'
      }.merge!(params)
    end

    # Lists all torrents.
    # Accepts query parameters from +params+.
    # Returns an array of hashes.
    def list(params = {})
      call({ 'mode' => 'list' }, params)
    end

    # Searches torrents by literal name from +string+.
    # Accepts query parameters from +params+.
    # Returns an array of hashes of matching elements.
    # Raises APIError if no results are found.
    def search_string(string, params = {})
      call({ 'mode' => 'search', 'search_string' => string }, params)
    end

    # Searches by IMDb ID from +imdbid+.
    # Accepts query parameters from +params+.
    # Returns an array of hashes of matching elements.
    # Raises APIError if no results are found.
    def search_imdb(imdbid, params = {})
      imdbid = "tt#{imdbid}" unless imdbid =~ /^tt\d+$/
      call({ 'mode' => 'search', 'search_imdb' => imdbid }, params)
    end

    # Searches by TVDB ID from +tvdbid+.
    # Accepts query parameters from +params+.
    # Returns an array of hashes of matching elements.
    # Raises APIError if no results are found.
    def search_tvdb(tvdbid, params = {})
      call({ 'mode' => 'search', 'search_tvdb' => tvdbid }, params)
    end

    # Searches by The Movie Database ID from +themoviedbid+
    # Accepts query parameters from +params+.
    # Returns an array of hashes of matching elements.
    # Raises APIError if no results are found.
    def search_themoviedb(themoviedbid, params = {})
      call({ 'mode' => 'search', 'search_themoviedb' => themoviedbid }, params)
    end

    private

    # Performs API call.
    def call(method_params, custom_params)
      raise ArgumentError, 'not an Hash' unless custom_params.is_a?(Hash)
      check_token

      res = request.get do |req|
        req.params.merge!(@default_params)
        req.params.merge!(custom_params)
        req.params.merge!(method_params)

        req.params['app_id'] = APP_ID
        req.params['token'] = @token
      end
      raise RequestError, res.reason_phrase unless res.success?
      raise APIError, res.body['error'] if res.body['error']

      res.body['torrent_results']
    end

    # Checks if +token+ is empty or expired.
    def check_token
      get_token if @token.nil? || (Time.now - @token_time) >= TOKEN_EXPIRATION
    end

    # Requests or renews API token.
    def get_token
      res = request.get do |req|
        req.params['get_token'] = 'get_token'
      end
      raise RequestError, res.reason_phrase unless res.success?
      raise APIError, res.body['error'] if res.body['error']
      sleep 2

      @token_time = Time.now
      @token = res.body['token']
    end

    # Setups Faraday request.
    def request
      Faraday.new(url: API_ENDPOINT) do |faraday|
        faraday.response :json
        faraday.request  :url_encoded
        faraday.adapter  Faraday.default_adapter
      end
    end
  end
end
