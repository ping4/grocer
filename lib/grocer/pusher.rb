require 'forwardable'
module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close

    ERROR_CODES={
      0 => "No errors encountered",
      1 => "Processing error",
      2 => "Missing device token",
      3 => "Missing topic",
      4 => "Missing payload",
      5 => "Invalid token size",
      6 => "Invalid topic size",
      7 => "Invalid payload size",
      8 => "Invalid token",
      255 => "None (unknown)"
    }

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
        if error = @connection.read_noblock(6)
          close
          e = error.unpack("c1c1N1")
          return { identifier: e[2], error_code: e[1], error_text: ERROR_CODES[e[1]] }
        end
      end
    end
  end
end
