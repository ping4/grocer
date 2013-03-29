require 'grocer'
require 'grocer/ssl_connection'
require 'forwardable'

module Grocer
  class Connection
    extend Forwardable
    attr_reader :retries, :ssl

    def_delegators :ssl, :connect, :close
    def_delegators :ssl, :certificate, :passphrase, :gateway, :port

    def initialize(options = {})
      @retries = options.fetch(:retries) { 3 }
      @ssl = Grocer::SSLConnection.new(options)
    end

    def read(size = nil, buf = nil)
      with_connection do
        ssl.read(size, buf)
      end
    end

    def read_with_timeout(*args)
      ssl.read_with_timeout(*args) if ssl
    end

    def write(content)
      with_connection do
        ssl.write(content)
      end
    end

    private

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

        close
        attempts += 1
        retry
      end
    end
  end
end
