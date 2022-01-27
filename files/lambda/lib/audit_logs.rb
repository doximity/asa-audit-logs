# frozen_string_literal: true

require "aws-sdk-ssm"
require "json"
require "link-header-parser"
require "logger"
require "log_formatter"
require "log_formatter/ruby_json_formatter"
require "net/https"
require "uri"
require "time_difference"

require_relative "ssm_client"

class AuditLogs
  attr_reader :asa_token, :log, :current_time

  def initialize()
    @current_time = Time.now.utc.iso8601

    @asa_token = get_asa_api_token
    @last_response = ""

    @log = Logger.new($stdout)
    @log.formatter = Ruby::JSONFormatter::Base.new do |config|
      config[:type] = false
      config[:app] = false
    end
  end

  def run
    collect_audit_logs 
    log.info({ message: "API requests left: #{@last_response.to_h["x-ratelimit-remaining"]}",
               ratelimit_remaining: @last_response.to_h["x-ratelimit-remaining"],
               event_type: "api_ratelimit_renamining", method: "run", env: ENV["ENVIRONMENT"] })
  end

  def get_asa_api_token
    asa_api_key = SSMClient.new.get_parameter(ENV["ASA_API_KEY_PATH"])
    asa_api_secret = SSMClient.new.get_parameter(ENV["ASA_API_SECRET_PATH"])

    uri = URI.parse("https://app.scaleft.com/v1/teams/#{ENV["ASA_TEAM"]}/service_token")
    data = { "key_id": asa_api_key.to_s,
             "key_secret": asa_api_secret.to_s }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type': "application/json")
    request.body = data.to_json
    response = http.request(request)
    result = JSON.parse(response.body)
    @last_response = response.each_header
    result["bearer_token"]
  end

  def collect_audit_logs
    query_path = "https://app.scaleft.com/v1/teams/#{ENV["ASA_TEAM"]}/auditsV2?descending=true"
    loop do

      uri = URI.parse(query_path)
      header = { 'Content-Type': "application/json", 'Authorization': "Bearer #{asa_token}" }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri, header)
      response = http.request(request)
      results = JSON.parse(response.body)["list"]
      related_objects = JSON.parse(response.body)["related_objects"]
      @last_response = response.each_header

      break if response["link"].nil?

      link_header = LinkHeaderParser.parse(response["link"], base: "https://app.scaleft.com/v1/").first
      query_path = link_header.target_uri

      break unless results.each do |event|
        unless event["timestamp"].nil?
          break if TimeDifference.between(@current_time,Time.parse(event["timestamp"])).in_minutes > ENV["TIME_INTERVAL"].to_i
          event = add_related_object_data(related_objects,event)
          log.info({ message: event.to_s, event_type: "event", method: "collect_audit_logs", env: ENV["ENVIRONMENT"] })
        end
      end
    end
  end

  def add_related_object_data(related_objects,event)
    if event['details'].key?('client')
      event['details']['client'] = related_objects[event['details']["client"]]['object']
    end
    if event['details'].key?('user') && !event['details']["user"].empty?
      event['details']['user'] = related_objects[event['details']["user"]]['object']
    end
    if event['details'].key?('project')
      event['details']['project'] = related_objects[event['details']["project"]]['object']
    end
    if event['details'].key?('server')
      event['details']['server'] = related_objects[event['details']["server"]]['object']
    end
    if event['details'].key?('actor')
      event['details']['actor'] = related_objects[event['details']["actor"]]['object']
    end
    if event['details'].key?('servers')
      server_array = []
      event['details']['servers'].each do |server|
        server_array.push(related_objects[server]['object'])
      end
      event['details']['servers'] = server_array
    end
    return event
  end
end
