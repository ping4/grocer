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

    def push_and_check(notification, timeout=nil)
      push(notification)
      read_errors(timeout)
    end

    def push_and_check_batch(notifications, final_timeout = 1.0)
      errors = []
      notifications.each_with_index { |n, i| n.identifier = i }

      i = 0
      while (i < notifications.length)
        notification = notifications[i]

        #block on the last message out by sending a timeout
        timeout = (i == notifications.length - 1) ? final_timeout : nil

        if error = push_and_check(notification, timeout)
          i = notifications.index { |n| n.identifier == error[:identifier] }
          error[:notification] = notifications[i]
          errors << error
        end
        i += 1
      end
      errors
    end

    # pass no timeout to not block (typical use case)
    # pass a timeout to block for a certain amount of time (use when you are done sending)
    def read_errors(timeout = nil)
      read, write, err = @connection.select(timeout)
      if read && read.first
        if error = @connection.read(6)
          close
          e = error.unpack("c1c1N1")
          return { identifier: e[2], error_code: e[1] }
        end
      end
    end
  end
end
