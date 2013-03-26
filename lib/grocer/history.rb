module Grocer
  # Keeps the most recent history of notifications sent
  #
  class History
    DEFAULT_SIZE = 100
    attr_reader :history, :lock

    def initialize(options)
      @lock = Mutex.new
      @size = options.fetch(:size, DEFAULT_SIZE) + 1
      erase_history
    end

    def remember(element)
      synchronize do
        @history[@f] = element
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
    def find_culpret(notifications=[], &block)
      hit    = nil

      synchronize do
        # handle left half of buffer for a buffer that wraps the end of the array
        if @f < @b
          hit = simple_scan(0, notifications, &block)
          @f = @size
        end

        #handle buffer front down to the back (where @f > @b or @f == @b)
        hit ||= simple_scan(@b, notifications, &block)
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

    def simple_scan(bottom, notifications=[], &block)
      while @f > bottom
        @f -= 1
        cur = @history[@f]
        @history[@f] = nil

        return cur if block.yield cur
        notifications << cur
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
