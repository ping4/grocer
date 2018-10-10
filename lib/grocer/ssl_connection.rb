require 'socket'
require 'openssl'
require 'forwardable'
require 'stringio'

module Grocer
  class SSLConnection
    extend Forwardable
    def_delegators :@ssl, :write, :read

    attr_accessor :certificate, :passphrase, :gateway, :port, :retries, :timeout

    def initialize(options = {})
      @certificate = options.fetch(:certificate) { nil }
      @passphrase = options.fetch(:passphrase) { nil }
      @gateway = options.fetch(:gateway) { fail NoGatewayError }
      @port = options.fetch(:port) { fail NoPortError }
      @retries = options.fetch(:retries) { 3 }
      @timeout = options.fetch(:write_timeout) { 10 } #seconds
    end

    def connected?
      !@ssl.nil?
    end

    def connect
      #puts "open connected=#{connected?}"
      return if connected?
      
      puts "4kk3"
      
      if ! @context
        @context = OpenSSL::SSL::SSLContext.new

        if certificate
          raise "(3599) #{certificate}"
          
          if certificate.respond_to?(:read)
            cert_data = certificate.read
            certificate.rewind if certificate.respond_to?(:rewind)
          else
            cert_data = File.read(certificate)
          end

          @context.key  = OpenSSL::PKey::RSA.new(cert_data, passphrase)
          @context.cert = OpenSSL::X509::Certificate.new(cert_data)
        end
      end

      secs      = @timeout.to_i
      usecs     = ((@timeout - secs) * 1_000_000).to_i
      c_timeout = [secs, usecs].pack("l_2")

      @sock            = TCPSocket.new(gateway, port)
      @sock.setsockopt   Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
      @sock.setsockopt   Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, c_timeout
      @sock.setsockopt   Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, c_timeout
      @ssl             = OpenSSL::SSL::SSLSocket.new(@sock, @context)
      @ssl.sync        = true
      @ssl.connect
    end

    # timeout of nil means block regardless. so just say it is ready
    # timeout of 0 means don't block / get quick answer. so select on read and write
    # timeout of number means block that long. so select on socket read only
    # returns: [can_read, can_write]
    # NOTE: returns true when connection closed. read will then return nil
    def select(read=true, write=true, timeout=0)
      if connected?
        if timeout
          can_read, can_write, can_err = IO.select(read ? [@ssl] : [], write ? [@ssl] : [], [@ssl], timeout)
          raise EOFError.new("closed stream") if can_err && can_err[0]
          [ !! can_read && !! can_read.first , !! can_write && !! can_write.first ]
        else
          [true, true]
        end
      else
        [false, false]
      end
    end

    # reads if there is an error on the socket
    # throws an EOFError if the connection is closed
    def read_if_ready(length, timeout=0)
      if select(true, timeout==0, timeout).first
        ret = read(length)
        raise EOFError.new("closed stream") unless ret
        ret
      end
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
