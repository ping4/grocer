require 'forwardable'

module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close
    ## if true, resend all recent notifications when the culpret notification is not found
    attr_accessor :resend_on_not_found

    def initialize(connection, options={})
      @connection = connection
      @previous_notifications = Grocer::History.new(size: options[:history_size])
      @resend_on_not_found = options[:resend_on_not_found] || false
    end

    def push(notification)
      remember_notification(notification)

      error_response = nil
      @connection.with_retry do |connection, exception|
        puts "push >>: #{connection ? "connection" : "exception"} - #{notification.alert}"
        if connection
          # this sometimes doesn't error, even though the connection is bad and the message is lost
          puts "push:push_out (#{@connection.connected? ? "connected" : "disconnected"})"
          push_out(notification) unless error_response
          error_response ||= read_error
          # on a closed connection, read_error will throw an error, and message will be retried
        end

        if exception
          puts "push caught err: #{exception}"
          # this is called from rescue, don't throw errors
          error_response ||= read_error rescue nil
          true
        end
      end
      notification.mark_sent
      clarify_response(error_response)
    end

    # public
    def push_and_retry(notifications, errors=[])
      notifications = Array(notifications)
      puts "par: [#{notifications.size}]"
      Array(notifications).each do |notification|
        response = push(notification)
        resend_notification(response, errors) if response #failed during push
      end
      puts "par: [#{notifications.size}]: #{Array(notifications).map(&:identifier).join(",")}]"
      errors
    end

    # private
    # basic read error, need to clarify to find notification
    def read_error(timeout=0)
      if response = @connection.read_if_ready(Grocer::ErrorResponse::LENGTH, timeout)
        puts "read_error"
        close
        Grocer::ErrorResponse.from_binary(response)
      end
    end

    # going away
    def read_error_and_history(timeout=0)
      clarify_response(read_error(timeout))
    end

    # public
    def check_and_retry(errors=[], timeout=0)
      if response = read_error(timeout)
        clarify_response(response)
        resend_notification(response, errors)
      end
      errors
    end

    def remembered_notifications?
      !@previous_notifications.empty?
    end

    def clear_notifications
      @previous_notifications.clear
    end

    def inspect
      "#<Pusher>"
    end

    private

    # send notification over the wire
    # if the connection had an error (e.g.: closed), then see if there is an error
    def push_out(notification)
      @connection.write(notification.to_bytes)
    end

    # lookup the notification that caused the error response
    def clarify_response(response)
      return unless response
      if response.false_alarm?
        clear_notifications
      else
        @previous_notifications.find_culpret(response)
      end
      response
    end

    def resend_notification(response, errors)
      if ! response.false_alarm?
        puts "car: err=#{response.identifier} - retrying: #{response.resend.map(&:identifier).join(",")}"
        errors << response
        push_and_retry(response.resend, errors) if response.notification || resend_on_not_found
      else
        puts "car: false alarm"
      end
      errors
    end

    def remember_notification(notification)
      @previous_notifications.remember(notification)
    end
  end
end
