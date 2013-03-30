module Grocer
  class ErrorResponse
    STATUS_CODE_DESCRIPTIONS = {
      0 => 'No errors encountered',
      1 => 'Processing error',
      2 => 'Missing device token',
      3 => 'Missing topic',
      4 => 'Missing payload',
      5 => 'Invalid token size',
      6 => 'Invalid topic size',
      7 => 'Invalid payload size',
      8 => 'Invalid token',
      256 => 'None (unknown)',
    }

    COMMAND = 8
    LENGTH  = 6

    attr_accessor :status_code, :identifier

    # what notification caused this error
    attr_accessor :notification

    # notifications that were not sent as a result of this error
    attr_accessor :resend

    def initialize(binary_tuple)
      # C => 1 byte command (will be 1 to represent the protocol version)
      # C => 1 byte status
      # N => 4 byte identifier
      command, @status_code, @identifier = binary_tuple.unpack('CCN')
      raise InvalidFormatError unless @status_code && @identifier
      raise InvalidCommandError unless command == COMMAND
      @created_at = Time.now
    end

    def false_alarm?
      status_code == 0
    end

    def invalid_token?
      status_code == 8
    end

    def status
      STATUS_CODE_DESCRIPTIONS[status_code]
    end
  end
end
