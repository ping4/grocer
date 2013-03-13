module Grocer
  class Pusher
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
      notifications.each_with_index { |n, i| n[:identifier] = i }

      i = 0
      while (i < notifications.length)
        notification = notifications[i]

        #block on the last message out by sending a timeout
        timeout = (i == notifications.length) ? final_timeout : nil

        if error = push_and_check(notification, timeout)
          i = notifications.index { |n| n.identifier == error[:identifier] }
          error[:notification] = notifications[i]
          errors << error

          #if this is not single message error
          #  return errors
          #end
        end
        i += 1
      end
      errors
    end

    # pass no timeout to not block (typical use case)
    # pass a timeout to block for a certain amount of time (use when you are done sending)
    def read_errors(timeout = nil)
      errors = []
      read, write, err = select(timeout)
      if err && err.first
        errors << {identifier: 'unexpected error while reading errors'}
      end
      if read && read.first
        while error_hash = read_error
          errors << error_hash
        end
      end

      close if errors.count > 0 
      errors
    end

    def read_error
      if error = @connection.gets
        e = error.unpack("c1c1N1")
        { identifier: e[2], error_code: e[1] }
      end
    end

    def select(timeout)
      @connection.select(timeout)
    end

    def connect
      @connection.connect
    end

    def close
      @connection.close
    end
  end
end
