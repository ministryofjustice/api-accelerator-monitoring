#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'httparty'
require 'ap'

#
### Global Config
#
# httptimeout => Number in seconds for HTTP Timeout. Set to ruby default of 60 seconds.
# ping_count => Number of pings to perform for the ping method
#
HTTP_TIMEOUT = 60
PING_COUNT = 10

#
# Check whether a server is Responding you can set a server to
# check via http request or ping
#
# Server Options
#   name
#       => The name of the Server Status Tile to Update
#   url
#       => Either a website url or an IP address. Do not include https:// when using ping method.
#   method
#       => http
#       => ping
#   info
#       => a boolean to detail wether to check the /info url as well as /health
#
# Notes:
#   => If the server you're checking redirects (from http to https for example)
#      the check will return false
#

servers = [
  {
    name: 'delius-api-dev',
    url: 'http://deliusapi-dev.sbw4jt6rsq.eu-west-2.elasticbeanstalk.com/api/health',
    info: 'http://deliusapi-dev.sbw4jt6rsq.eu-west-2.elasticbeanstalk.com/api/info'
  },
  #{ name: 'delius-api-stage', url: 'http://deliusapi-stage.xxxxxx.eu-west-2.elasticbeanstalk.com/api/health' },
  #{ name: 'delius-api-prod', url: 'http://deliusapi-prod.xxxxxx.eu-west-2.elasticbeanstalk.com/api/health' },

  { name: 'delius-api-job-schedular-dev', url: 'http://delius-api-job-schedular-dev.tqek38d8jq.eu-west-2.elasticbeanstalk.com/health' },
  #{ name: 'delius-api-job-schedular-prod', url: 'http://delius-api-job-schedular-prod.xxxxxx.eu-west-2.elasticbeanstalk.com/health' },

  { name: 'rsr-calculator-service-dev', url: 'https://health-kick.hmpps.dsd.io/https/rsr-dev.hmpps.dsd.io' },
  { name: 'rsr-calculator-service-prod', url: 'https://health-kick.hmpps.dsd.io/https/rsr.service.hmpps.dsd.io' },

  { name: 'viper-service-dev', url: 'https://health-kick.hmpps.dsd.io/https/viper-dev.hmpps.dsd.io' },
  { name: 'viper-service-prod', url: 'https://health-kick.hmpps.dsd.io/https/viper.service.hmpps.dsd.io' },
]

def gather_health_data(server)

  begin
    health = HTTParty.get("#{server[:url]}", headers: { 'Accept' => 'application/json' }, timeout: 5)

    if server[:info]
      info = HTTParty.get("#{server[:info]}", headers: { 'Accept' => 'application/json' }, timeout: 5)
    end

    return {
        status: health['status'] || health['healthy'] ? 'UP' : 'DOWN',
        version: health['version'] || 'N/A',
        uptime: health['uptime'] || 'N/A',
        ldap: health['ldap'] ? health['ldap']['status'] : 'N/A',
        db: health['db'] ? health['db']['status'] : health['checks'] ? health['checks']['db'] : 'N/A',
        gitRef: server[:info] ? info['git']['commit']['id'] : health['build'] ? health['build']['gitRef'][0...7] : 'N/A'
    }
    rescue HTTParty::Error => expection
        ap expection.class
        return { status: 'error', gitRef: expection.class, ldap: "N/A", db: "N/A" }
    rescue StandardError => expection
        ap expection.class
        return { status: 'error', gitRef: expection.class, ldap: "N/A", db: "N/A" }
    end
end

SCHEDULER.every '60s', first_in: 0 do |_job|
  servers.each do |server|
    result = gather_health_data(server)
    send_event(server[:name], result: result)
  end
end
