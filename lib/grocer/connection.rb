require 'grocer'
require 'grocer/ssl_connection'
require 'forwardable'

module Grocer
  class Connection
    extend Forwardable
    attr_reader :retries, :ssl

    def_delegators :ssl, :connect, :close, :ready?, :read, :write
    #for tests - deprecate
    def_delegators :ssl, :certificate, :passphrase, :gateway, :port

    def initialize(options = {})
      @retries = options.fetch(:retries) { 3 }
      @ssl = Grocer::SSLConnection.new(options)
    end

    def with_retry(&block)
      attempts = 1 ##
      begin
        connect
        block.yield ssl
      rescue => e
        if e.class == OpenSSL::SSL::SSLError && e.message =~ /certificate expired/i
          e.extend(CertificateExpiredError)
          raise
        end
        if block.arity == 2
          raise unless block.call(nil, e)
        else
          raise unless attempts < retries
        end

        close
        attempts += 1
        retry
      end
    end
  end
end
