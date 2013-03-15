require 'forwardable'

module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close

    def initialize(connection)
      @connection = connection
    end

    def push(notification)
      @connection.write(notification.to_bytes)
    end
    def has_errors?
      @connection.pending > 0
    end

  end
end
