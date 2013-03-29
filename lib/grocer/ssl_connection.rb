require 'socket'
require 'openssl'
require 'forwardable'
require 'stringio'

module Grocer
  class SSLConnection
    extend Forwardable
    def_delegators :@ssl, :write, :read

    attr_accessor :certificate, :passphrase, :gateway, :port

    def initialize(options = {})
      @certificate = options.fetch(:certificate) { nil }
      @passphrase = options.fetch(:passphrase) { nil }
      @gateway = options.fetch(:gateway) { fail NoGatewayError }
      @port = options.fetch(:port) { fail NoPortError }
    end

    def connected?
      !@ssl.nil?
    end

    def connect
      return if connected?
      context = OpenSSL::SSL::SSLContext.new

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

      @sock            = TCPSocket.new(gateway, port)
      @sock.setsockopt   Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
      @ssl             = OpenSSL::SSL::SSLSocket.new(@sock, context)
      @ssl.sync        = true
      @ssl.connect
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
