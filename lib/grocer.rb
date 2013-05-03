require 'grocer/error_response'
require 'grocer/feedback'
require 'grocer/history'
require 'grocer/mobile_device_management_notification'
require 'grocer/newsstand_notification'
require 'grocer/notification'
require 'grocer/passbook_notification'
require 'grocer/pusher'
require 'grocer/server'
require 'grocer/ssl_connection'
require 'grocer/version'

module Grocer
  Error = Class.new(::StandardError)
  InvalidFormatError = Class.new(Error)
  NoGatewayError = Class.new(Error)
  NoPayloadError = Class.new(Error)
  NoPortError = Class.new(Error)
  PayloadTooLargeError = Class.new(Error)
  CertificateExpiredError = Module.new
  InvalidCommandError = Class.new(Error)

  def self.env
    ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
  end

  def self.feedback(options)
    Feedback.new(connection(options, 2196,
      'production' => 'feedback.push.apple.com',
      'sandbox' => 'feedback.sandbox.push.apple.com'
    ))
  end

  def self.pusher(options)
    Pusher.new(connection(options, 2195,
      'production' => 'gateway.push.apple.com',
      'test' => '127.0.0.1',
      'sandbox' => 'gateway.sandbox.push.apple.com'
    ))
  end

  def self.server(options = { })
    ssl_server = SSLServer.new(options)
    Server.new(ssl_server)
  end

  private

  def self.connection(options, port, servers)
    options.extend Extensions::DeepSymbolizeKeys
    SSLConnection.new(
      {
        gateway: servers[env.downcase] || servers['sandbox'],
        port: port
      }.merge(options.deep_symbolize_keys)
    )
  end
end
