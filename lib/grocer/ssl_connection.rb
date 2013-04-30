require 'socket'
require 'openssl'
require 'forwardable'
require 'stringio'

module Grocer
  class SSLConnection
    extend Forwardable
    def_delegators :@ssl, :write, :read

    attr_accessor :certificate, :passphrase, :gateway, :port, :retries, :context

    def initialize(options = {})
      @certificate = options.fetch(:certificate) { nil }
      @passphrase = options.fetch(:passphrase) { nil }
      @gateway = options.fetch(:gateway) { fail NoGatewayError }
      @port = options.fetch(:port) { fail NoPortError }
      @retries = options.fetch(:retries) { 3 }
    end

    def connected?
      !@ssl.nil?
    end

    def connect
      #puts "open connected=#{connected?}"
      return if connected?

      if ! context
        self.context = OpenSSL::SSL::SSLContext.new

        if certificate
          if certificate.respond_to?(:read)
            cert_data = certificate.read
            certificate.rewind if certificate.respond_to?(:rewind)
          else
            cert_data = File.read(certificate)
          end

          context.key  = OpenSSL::PKey::RSA.new(cert_data, passphrase)
          context.cert = OpenSSL::X509::Certificate.new(cert_data)
        end
      end

      @sock            = TCPSocket.new(gateway, port)
      @sock.setsockopt   Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
      @ssl             = OpenSSL::SSL::SSLSocket.new(@sock, context)
      @ssl.sync        = true
      @ssl.connect
    end

    # timeout of nil means block regardless. so just say it is ready
    # timeout of 0 means don't block / get quick answer. so select on read and write
    # timeout of number means block that long. so select on socket read only
    def ready?(timeout=0)
      if connected?
        if timeout
          write_arr = timeout == 0 ? [@ssl] : nil
          read_arr, _, _ = IO.select([@ssl],write_arr,[@ssl], timeout) || [[]]
          read_arr && !! read_arr.first
        else
          true
        end
      end
    end

    # even if ready? returns true, there can still be a closed connection
    def read_if_ready(length, timeout=0)
      read(length) if ready?(timeout)
    end

    def with_retry(&block)
      attempts = 1
      begin
        connect
        block.yield self
      rescue => e
        if e.class == OpenSSL::SSL::SSLError && e.message =~ /certificate expired/i
          e.extend(CertificateExpiredError)
          raise
        end
        block.call(nil, e) if block.arity == 2
        close
        raise unless attempts < retries
        attempts += 1
        retry
      end
    end

    def close
      @ssl.close rescue nil if @ssl
      @ssl = nil

      @sock.close rescue nil if @sock
      @sock = nil
    end

    def reconnect
      close
      connect
    end
  end
end
