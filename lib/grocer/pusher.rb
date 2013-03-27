require 'forwardable'

module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close

    def initialize(connection)
      @connection = connection
      @backlog    = RBuffer.new(20)
      @identifier = 0
    end

    def push(notification)
      @connection.write(notification.to_bytes)
    end

    def read_errors(timeout=0.0)
      if @connection.can_read?(timeout)
        response = @connection.read_if_connected(6)
        close
        #NOTE: if response.nil? then we probably dropped an error on the floor
        ErrorResponse.new(response) if response
      end
    end

    def push_and_check(notification, timeout=0)
      remember_notification notification
      push notification
      read_errors
    end

    def push_and_retry(notifications, errors=[])
      notifications=Array(notifications)
      while notification = notifications.shift
        if response = push_and_check(notification)
          errors << response
          notification_to_retry(response).each do |n|
            notifications << n
          end
        end
      end
      errors
    end

    def check_and_retry(errors=[])
      if response = read_errors
        errors << response
        notifications=[]
        push_and_retry(notification_to_retry(response), errors)
      end
      errors
    end

    def remembered_notifications?
      !@backlog.empty?
    end

    def clear_notifications
      @backlog.clear
    end

    private

    def remember_notification(notification)
      notification.identifier = next_identifier
      @backlog.put notification
    end

    def notification_to_retry(response)
      response.notification, retries = @backlog.scan {|n| n.identifier == response.identifier}
      retries
    end

    def next_identifier
      if @identifier > 2000
        @identifier  = 1
      else
        @identifier += 1
      end
    end
  end
end
