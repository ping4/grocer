require 'forwardable'

module Grocer
  class Pusher
    extend Forwardable

    def_delegators :@connection, :connect, :close, :select
    ## if true, resend all recent notifications when the culpret notification is not found (default: false)
    attr_accessor :resend_on_not_found
    attr_accessor :connection

    def initialize(connection, options={})
      @connection = connection
      @previous_notifications = Grocer::History.new(size: options[:history_size])
      @resend_on_not_found = options[:resend_on_not_found] || false
    end

    def push(notification)
      remember_notification(notification)

      error_response = nil
      @connection.with_retry do |connection, exception|
        if connection
          error_response ||= read_error(0, true)
          #if we write before reading, we often block
          push_out(notification) unless error_response
        end

        if exception
          # this is called from the rescue block, don't throw errors
          error_response ||= read_error
          true
        end
      end
      notification.mark_sent
      clarify_response(error_response)
    end

    # public
    def push_and_retry(notifications, errors=[])
      Array(notifications).each do |notification|
        response = push(notification)
        resend_notification(response, errors) if response #failed during push
      end
      errors
    end

    # private
    # basic read error, need to clarify to find notification
    def read_error(timeout=0, raise_exception=false)
      begin
        if response = @connection.read_if_ready(Grocer::ErrorResponse::LENGTH, timeout)
          close
          Grocer::ErrorResponse.from_binary(response)
        end
      rescue EOFError
        close
        raise if raise_exception
      end
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
