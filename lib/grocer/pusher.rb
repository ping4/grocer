module Grocer
  class Pusher
    def initialize(connection)
      @connection = connection
    end

    def push(notification)
      @connection.write(notification.to_bytes)
    end

    def read_errors timeout = 0.5
      errors = []
    	read, write, error = @connection.select(timeout)
    	if !error.nil? && !error.first.nil?
	      Rails.logger.error "IO.select has reported an unexpected error while sending notifications."
	    end
	    if !read.nil? && !read.first.nil?
	      while error = read[0].gets
	      	e = error.unpack("c1c1N1")
	      	errors << {identifier: e[2], error_code: e[1]}
	      end
      end
      close if errors.count > 0 #force reestablish connection on next push
	    errors
    end

    def has_errors?
      @connection.pending > 0
    end

    def close
    	@connection.close
    end
  end
end
