require 'grocer'
require 'grocer/ssl_connection'
require 'forwardable'

module Grocer
  class Connection
    extend Forwardable
    attr_reader :certificate, :passphrase, :gateway, :port, :retries

    def_delegators :ssl, :connect, :disconnect, :can_read?

    def initialize(options = {})
      @certificate = options.fetch(:certificate) { nil }
      @passphrase = options.fetch(:passphrase) { nil }
      @gateway = options.fetch(:gateway) { fail NoGatewayError }
      @port = options.fetch(:port) { fail NoPortError }
      @retries = options.fetch(:retries) { 3 }
    end

    def read(size = nil, buf = nil)
      with_connection do
        ssl.read(size, buf)
      end
    end

    # we are reading off a possibly closed connection - don't open it
    def read_if_connected(size = nil, buf = nil)
      ssl.read(size, buf) if ssl && ssl.connected?
    end

    def write(content)
      with_connection do
        ssl.write(content)
      end
    end

    alias_method :close, :disconnect

    private

    def ssl
      @ssl_connection ||= build_connection
    end

    def build_connection
      Grocer::SSLConnection.new(certificate: certificate,
                                passphrase: passphrase,
                                gateway: gateway,
                                port: port)
    end

    def with_connection
      attempts = 1
      begin
        connect
        yield
      rescue => e
        if e.class == OpenSSL::SSL::SSLError && e.message =~ /certificate expired/i
          e.extend(CertificateExpiredError)
          raise
        end

        raise unless attempts < retries

        disconnect
        attempts += 1
        retry
      end
    end
  end
end
