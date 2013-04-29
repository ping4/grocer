require 'forwardable'

module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close
    ## send all of history if there was an error, but the identifier was not fond in history
    attr_accessor :resend_on_not_found


    def initialize(connection, options={})
      @connection = connection
      @previous_notifications = Grocer::History.new(size: options[:history_size])
      @resend_on_not_found = options[:resend_on_not_found] || false
    end

    def push(notification)
      remember_notification(notification)
      response = push_out(notification)
      notification.mark_sent
      response ||= read_error
      clarify_response(response)
    end

    def push_and_retry(notifications, errors=[])
      Array(notifications).each do |notification|
        response = push(notification)
        resend_notification(response, errors) if response #failed during push
      end
      errors
    end

    # private
    def read_error(timeout=0)
      if response = @connection.read_if_ready(Grocer::ErrorResponse::LENGTH, timeout)
        close
        Grocer::ErrorResponse.from_binary(response)
      end
    end

    # going away
    def read_error_and_history(timeout=0)
      clarify_response(read_error(timeout))
    end

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
      error_response = nil
      retries = 0
      @connection.with_retry do |connection, exception|
        @connection.write(notification.to_bytes) if connection
        if exception
          err = read_error
          error_response ||= err
          retries += 1
          retries < 3
        end
      end
      error_response
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
        errors << response
        push_and_retry(response.resend, errors) if response.notification || resend_on_not_found
      end
      errors
    end

    def remember_notification(notification)
      @previous_notifications.remember(notification)
    end
  end
end
