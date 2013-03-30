module Grocer
  # Keeps the most recent history of notifications sent
  #
  class History
    DEFAULT_SIZE = 100
    attr_reader :history, :lock
    attr_accessor :identifier
    attr_accessor :max_identifier

    def initialize(options)
      @lock = Mutex.new
      @size = (options[:size] || DEFAULT_SIZE) + 1
      @max_identifier = @size << 4
      erase_history
      @identifier = 0
    end

    def remember(notification)
      synchronize do
        notification.identifier ||= next_identifier
        @history[@f] = notification
        @f = (@f + 1) % @size

        if @f == @b     #full
          @history[@b] = nil
          @b = (@b + 1) % @size
        end
      end
    end

    #called in an error condition
    # start at the most recent, and scan backtwards until we find the notification of interest
    # notifications between now and the culpret will be put into notifications
    # the culpret will be returned
    # this will remove all entries sent (the connection is closed, so we won't put any more on this socket)
    def find_culpret(error_response, &block)
      error_response.resend ||= []
      hit    = nil

      synchronize do
        # handle left half of buffer for a buffer that wraps the end of the array
        if @f < @b
          hit = simple_scan(0, error_response, &block)
          @f = @size
        end

        #handle buffer front down to the back (where @f > @b or @f == @b)
        hit ||= simple_scan(@b, error_response, &block)
        erase_history
      end

      hit
    end

    # total entries in the queue (informational only)
    def size
      synchronize do
        (@f - @b + @size) % @size
      end
    end

    # the queue is empty
    def empty?
      @f == @b
    end

    #when the connection is closed, we don't need to remember these anymore

    def clear
      synchronize do
        erase_history
      end
    end

    private

    # the next identifier to assign to the notification
    # give a little padding to ensure there is no confusion

    def next_identifier
      if @identifier >= @max_identifier
        @identifier = 1
      else
        @identifier += 1
      end
    end


    def simple_scan(bottom, error_response, &block)
      while @f > bottom
        @f -= 1
        cur = @history[@f]
        @history[@f] = nil

        if error_response.identifier == cur.identifier
          error_response.notification = cur
          return error_response
        end
        error_response.resend << cur
      end
      nil
    end

    def erase_history
      @history = Array.new(@size)
      @f = @b = 0
    end

    def synchronize(&block)
      lock.synchronize(&block)
    end
  end
end
