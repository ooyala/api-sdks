# Copyright 2011 © Ooyala, Inc.  All rights reserved.
#
# Ooyala, Inc. (“Ooyala”) hereby grants permission, free of charge, to any
# person or entity obtaining a copy of the software code provided in source
# code format via this webpage and direct links contained within this webpage
# and any associated documentation (collectively, the "Software"), to use,
# copy, modify, merge, and/or publish the Software and, subject to
# pass-through of all terms and conditions hereof, permission to transfer,
# distribute and sublicense the Software; all of the foregoing subject to the
# following terms and conditions:
#
# 1.   The above copyright notice and this permission notice shall be included
#      in all copies or portions of the Software.
#
# 2.   For purposes of clarity, the Software does not include any APIs, but
#      instead consists of code that may be used in conjunction with APIs that
#      may be provided by Ooyala pursuant to a separate written agreement
#      subject to fees.
#
# 3.   Ooyala may in its sole discretion maintain and/or update the Software.
#      However, the Software is provided without any promise or obligation of
#      support, maintenance or update.
#
# 4.   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND
#      NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#      LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#      OF CONTRACT, TORT OR OTHERWISE, RELATING TO, ARISING FROM, IN
#      CONNECTION WITH, OR INCIDENTAL TO THE SOFTWARE OR THE USE OR OTHER
#      DEALINGS IN THE SOFTWARE.
#
# 5.   TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, (i) IN NO EVENT
#      SHALL OOYALA BE LIABLE FOR ANY CONSEQUENTIAL, INCIDENTAL, INDIRECT,
#      SPECIAL, PUNITIVE, OR OTHER DAMAGES WHATSOEVER (INCLUDING, WITHOUT
#      LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS
#      INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS)
#      RELATING TO, ARISING FROM, IN CONNECTION WITH, OR INCIDENTAL TO THE
#      SOFTWARE OR THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF OOYALA
#      HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES, AND (ii) OOYALA’S
#      TOTAL AGGREGATE LIABILITY RELATING TO, ARISING FROM, IN CONNECTION
#      WITH, OR INCIDENTAL TO THE SOFTWARE SHALL BE LIMITED TO THE ACTUAL
#      DIRECT DAMAGES INCURRED UP TO MAXIMUM AMOUNT OF FIFTY DOLLARS ($50).
#
require 'rubygems'
require 'rest-client'
require 'base64'
require 'digest/sha2'
require 'cgi'
require 'json'

# Contains the necessary mehtods to communicate with the Ooyala's API.
module Ooyala
  class API
    SUPPORTED_HTTP_METHODS    = %w{GET POST PUT PATCH DELETE}
    DEFAULT_BASE_URL          = 'https://api.ooyala.com'
    DEFAULT_CACHE_BASE_URL    = 'https://cdn.api.ooyala.com'
    DEFAULT_EXPIRATION_WINDOW = 15
    ROUND_UP_TIME             = 300

    # Sets the String base URL (default: "https://api.ooyala.com").
    attr_writer :base_url

    # Sets the String cache base URL (default: "https://cdn.api.ooyala.com").
    attr_writer :cache_base_url

    # Sets the Number with the expiration window. This is added to the current
    # time. It should be in seconds, and represents the time that a request is
    # valid.
    attr_writer :expiration_window

    # Gets/Sets the String secret key. This can be found in Backlot's developers
    # tab (http://ooyala.com/backlot/web).
    attr_accessor :secret_key

    # Gets/Sets the API key. This can be found in Backlot's developers tab
    # (http://ooyala.com/backlot/web).
    attr_accessor :api_key

    # Gets the base URL. If no base URL is specified it will return the default
    # one.
    #
    # Returns the String base URL.
    def base_url
      @base_url || DEFAULT_BASE_URL
    end

    # Gets the cache base URL. If no base URL is specified it will return the
    # default one.
    #
    # Returns the String base URL.
    def cache_base_url
      @cache_base_url || DEFAULT_CACHE_BASE_URL
    end

    # Gets the default expiration window. If not specified, the default one.
    #
    # Returns the Number expiration window.
    def expiration_window
      @expiration_window || DEFAULT_EXPIRATION_WINDOW
    end

    # Initialize an API. Takes the secret and api keys. If these are not
    # specified the class properties will be used to make requests,
    # generate signatrues, etc.
    #
    #   secret_key - The String secret key.
    #   api_key    - The String API key.
    #   options    - The Hash options to specify extra settings for this API
    #                instance (default: {}):
    #                :cache_base_url    - The String cache base URL to override
    #                                     the default one.
    #                :base_url          - The String base URL to override the
    #                                     default one.
    #                :expiration_window - The Number in seconds to override the
    #                                     default value (optional).
    def initialize(api_key, secret_key, options = {})
      self.secret_key = secret_key
      self.api_key    = api_key
      self.base_url   = options[:base_url] || options['base_url']
      self.cache_base_url = options[:cache_base_url] ||
        options['cache_base_url']
      self.expiration_window = options[:expiration_window] ||
        options['expiration_window']
    end

    # Makes a GET request.
    #
    #   path         - The String relative path for the request.
    #   query_params - A Hash with GET parameters for the request (default: {}).
    #
    # Returns a the JSON parsed response. Could be either a Hash or Array.
    def get(path, query_params = {})
      send_request('GET', path, query_params)
    end

    # Makes a POST request.
    #
    #   path         - The String relatice path for the request.
    #   body         - An optional Object. If a Hash or Array, its contents will
    #                  be JSON enconded. If a File, it will be read, or anything
    #                  that responds to to_s (default: nil).
    #   query_params - A Hash with GET paramaters fo the request (default: {}).
    #
    # Examples
    #
    #     api.post('assets', File.open('my_video.avi'))
    #     api.post('labels', {:name => "Test"})
    #
    # Returns the body of the response.
    def post(path, body = nil, query_params = {})
      if Hash === body || Array === body
        body = body.to_json
      elsif File === body
        body = body.read
      end
      send_request('POST', path, query_params, body.to_s)
    end

    # Makes a PUT request.
    #
    #   path         - The String relative path for the request.
    #   body         - An optional Object. If a Hash or Array, its contents will
    #                  be JSON enconded. If a File, it will be read, or anything
    #                  that responds to to_s (default: nil).
    #   query_params - A Hash with GET paramaters fo the request (default: {}).
    #
    # Returns the body of the response.
    def put(path, body = nil, query_params = {})
      if Hash === body || Array === body
        body = body.to_json
      elsif File === body
        body = body.read
      end
      send_request('PUT', path, query_params, body.to_s)
    end

    # Makes a PATCH request.
    #
    #   path         - The String relative path for the request.
    #   body         - The Hash with the properties to update (default: {}).
    #   query_params - A Hash with GET paramaters fo the request (default: {}).
    #
    # Returns the body of the response.
    def patch(path, body = {}, query_params = {})
      send_request('PATCH', path, query_params, body.to_json)
    end

    # Makes a DELETE request.
    #
    #   path         - The String relative path for the request.
    #   query_params - A Hash with GET paramaters fo the request (default: {}).
    #
    # Returns the body of the response.
    def delete(path, query_params = {})
      send_request('DELETE', path, query_params)
    end

    # Generates the signature for a request, using a body in the request.
    # If the method is a GET, then it does not need the body. On the other hand
    # if it is a POST, PUT or PATCH, the body is a string with the parameters
    # that are going to be modified, or assigned to the resource. This should be
    # later added to the query parameters, as the signature parameter of the
    # desired requested URI.
    #
    # http_method  - The String HTTP method. It could be either GET, DELETE,
    #                POST, PUT or PATCH.
    # request_path - The String with the path of the resourcce of the request.
    # query_params - The Hash that contains GET query paramaters (default: {}).
    # request_body - An String that contains the POST request body
    #                (default: "").
    #
    # Returns the signature that should be added as query parameter to the URI
    # of the request.
    def generate_signature(http_method, request_path, query_params = {},
                           request_body = '')
      string_to_sign  = secret_key
      string_to_sign += http_method.to_s.upcase + request_path
      sorted_params   = query_params.sort { |a, b| a[0].to_s <=> b[0].to_s }
      string_to_sign += sorted_params.map { |param| param.join('=') }.join
      string_to_sign += request_body.to_s

      signature = Base64::encode64(Digest::SHA256.digest(string_to_sign))[0..42]
      CGI.escape(signature)
    end

    # Creates a request to a given path using the indicated HTTP Method.
    #
    # http_method  - The String HTTP method that contains either GET, DELETE,
    #                POST, PUT or PATCH.
    # query_params - The Hash that contains GET query parameters (default: {}).
    # request_path - The String with the relative path of the request.
    # request_body - An String that contains the POST request body
    #                (default: "").
    #
    # Returns the Array or Hash with the JSON parsed response if it was success.
    # Raises Ooyala::MethodNotSupportedException if the HTTP method is not
    # supported.
    # Raises Ooyala::RequestErrorException if there was an error sending the
    # request.
    def send_request(http_method, request_path, query_params = {},
                     request_body = nil)
      http_method = http_method.to_s.upcase
      unless SUPPORTED_HTTP_METHODS.include? http_method
        raise Ooyala::MethodNotSupportedException
      end

      request_path = '/v2/' + request_path unless request_path[0..3] == '/v2/'
      original_params = Hash[*query_params.map { |k,v| [k.to_sym, v] }.flatten]
      query_params = sanitize_and_add_needed_parameters(query_params)
      query_params[:signature] ||= generate_signature(http_method,
                                    request_path,
                                    query_params.merge(original_params),
                                    request_body)

      request = RestClient::Request.new\
        :method  => http_method.to_s.downcase.to_sym,
        :url     => build_url(http_method, request_path, query_params),
        :payload => request_body

      response = request.execute

      return [] if response.body.empty?
      JSON.parse(response.body)
    rescue RestClient::Exception => ex
      raise Ooyala::RequestErrorException.new(ex.inspect)
    end

    # Builds the URL for a request. Adds the query parameters, the signature
    # and expiration.
    #
    # http_method  - The String request HTTP method. It could be 'GET',
    #                'POST', 'PUT', 'PATCH' or 'DELETE'.
    # request_path - The String absolute path for this URL.
    # query_params - The Hash with the parameters to be added to the URL
    #                (default: {}).
    #
    # Returns a String with the built URL.
    def build_url(http_method, request_path, query_params = {})
      url  = http_method == 'GET' ? cache_base_url : base_url
      url += request_path + '?'
      url + query_params.sort { |a, b| a[0].to_s <=> b[0].to_s }.map do |param|
        param.join("=")
      end.join("&")
    end

    private
    def sanitize_and_add_needed_parameters(params)
      params = Hash[*params.map { |k,v| [k.to_sym, CGI.escape(v.to_s)] }.flatten]

      params[:expires] ||= begin
        expiration = Time.now.to_i + expiration_window
        expiration + ROUND_UP_TIME - (expiration%ROUND_UP_TIME)
      end
      params[:api_key] ||= api_key
      params
    end
  end

  class RequestErrorException < StandardError
  end

  class MethodNotSupportedException < StandardError
  end
end
