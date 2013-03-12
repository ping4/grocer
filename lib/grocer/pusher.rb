module Grocer
  class Pusher
    def initialize(connection)
      @connection = connection
    end

    def push(notification)
      @connection.write(notification.to_bytes)
    end

    def read_errors(timeout = 0.5)
      errors = []
      read, write, error = select(timeout)
      if error && error.first
        errors << {identifier: 'unexpected error while reading errors'}
      end
      if read && read.first
        while error = read[0].gets
          e = error.unpack("c1c1N1")
          errors << {identifier: e[2], error_code: e[1]}
        end
      end
      close if errors.count > 0 #force reestablish connection on next push
      errors
    end

    def select(timeout)
      @connection.select(timeout)
    end

    def has_errors?
      @connection.pending > 0
    end

    def close
      @connection.close
    end
  end
end
