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
        ErrorResponse.new(@connection.read(6)).tap { close }
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
        notification_to_retry(response).each do |n|
          notifications << n
        end
        push_and_retry(notifications, errors)
      end
      errors
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
