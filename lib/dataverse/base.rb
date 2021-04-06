# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'rexml/document'

require 'forwardable'

module Dataverse
  class Base
    extend Forwardable

    attr_reader :api_data

    def_delegators :@api_data, :[], :fetch, :keys, :dig

    def refresh
      init(get_data)
    end

    protected

    def init(data)
      @api_data = data
      @api_data.freeze
    end

    def get_data
      @api_data
    end

    public

    def ==(other)
      self.api_data == other.api_data
    end

    def eql?(other)
      self == other
    end

    def hash
      api_data.hash
    end

    protected

    def api_call(url, **args)
      self.class.api_call(url, **args)
    end

    def self.api_call(url, method: :get, headers: {},  params: {}, body: nil, format: :api, block: nil, options: {})

      unless ENV.has_key?('API_URL') && ENV.has_key?('API_TOKEN')
        raise Error.new("Set environment variables 'API_URL' and 'API_TOKEN'")
      end

      url = ENV['API_URL'].chomp('/') + '/' + url.sub(/^\//, '')

      headers['X-Dataverse-key'] = ENV['API_TOKEN']
      headers[:params] = params unless params.empty?

      format = :block if block
      
      case format
      when :xml
        headers[:accept] = :xml
        headers[:content_type] ||= :xml
      when :api, :json
        headers[:accept] = :json
        headers[:content_type] ||= :json
      when :raw
        options[:raw_response] = true
      when :block
        options[:block_response] = block
      end

      body = body.to_json if body.is_a?(Hash) && headers[:content_type] == :json
      body = body.write if body.is_a?(REXML::Document) && headers[:content_type] == :xml

      response = RestClient::Request.execute(
        method: method,
        url: url,
        headers: headers,
        payload: body,
        # log: STDOUT,
        **options
      )

      case format
      when :api
        data = JSON.parse(response.body)
        raise Error.new(data['message']) unless data['status'] == 'OK'
        return data['data']
      when :xml
        REXML::Document.new(response.body)
      when :json
        return JSON.parse(response.body)
      when :raw, :block, :response
        return response
      when :status
        return response.code
      else
        return response.body
      end

    rescue RestClient::Exception => e
      if e.http_body =~ /^\s*{\s*"status"\s*:\s*"ERROR"\s*,\s*"message"\s*:\s*"/
        regex = /lib\/dataverse\/(?!.*:in\s*`.*(api_)?call'$)/
        raise Error.new(JSON.parse(e.http_body)['message'],
          backtrace: e.backtrace.drop_while {|x| !regex.match?(x)}
        )
      end
      raise
    end

  end
end

# if log = ENV['RESTCLIENT_LOG']
#   RestClient.log = STDOUT if log.upcase == 'STDOUT'
#   RestClient.log = STDERR if log.upcase == 'STDERR'
#   RestClient.log = log
# end
