require 'forwardable'

module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close

    def initialize(connection)
      @connection = connection
    end

    def push(notification)
      push_out(notification)
    end

    def read_error(timeout=0)
      if response = @connection.read_with_timeout(Grocer::ErrorResponse::LENGTH, timeout)
        close
        Grocer::ErrorResponse.new(response)
      end
    end

    def inspect
      "#<Pusher>"
    end

    private

    def push_out(notification)
      @connection.write(notification.to_bytes)
    end
  end
end
