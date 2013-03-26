# based upon https://github.com/bbcrd/CBuffer
# Original author Duncan Robertson <duncan.robertson at bbc.co.uk>
# Apache licensed
# Modifications Keenan Brock <keenan@thebrocks.net>
module Grocer
  class RBuffer
    def initialize(capacity)
      @capacity = capacity+1
      clear
    end

    def put(element)
      @buffer[@f] = element
      @f = (@f + 1) % @capacity
      #ran out of capacity, throw away the extra node
      pop if @f == @b
    end

    #start at the most recent, and scan backtwards until we found the record of interest
    def scan(&block)
      raise "no block given" unless block_given?
      hit    = nil
      misses = []

      # handle left half of buffer for a buffer that wraps the outside
      if @f < @b
        hit = simple_scan(0, misses, &block)
        clear_scan(0)

        #go to the right side of the buffer and continue from there
        @f = @capacity
      end

      #handle buffer down to the back
      hit ||= simple_scan(@b, misses, &block)
      clear_scan(@b)

      [hit, misses]
    end

    #for testing only
    def empty?
      @f == @b
    end

    def clear
      @buffer = Array.new(@capacity)
      @f = @b = 0
    end

    def to_s
      "<#{self.class} @b=#{@b} @f=#{@f} capacity=#{@capacity-1}"
    end

    private

    def simple_scan(bottom, misses=[], &block)
      while @f>bottom
        @f -= 1
        cur = @buffer[@f]
        @buffer[@f] = nil

        return cur if yield(cur)
        misses << cur
      end
      nil
    end

    def clear_scan(bottom)
      while @f > bottom
        @f-=1
        @buffer[@f] = nil
      end
    end

    def pop
      element = @buffer[@b]
      @buffer[@b] = nil
      @b = (@b + 1) % @capacity
      element
    end
  end
end
