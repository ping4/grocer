require 'grocer.rb'
require 'grocer/error_response'

describe Grocer::ErrorResponse do
  let(:status_code) { 1 }
  let(:identifier) { 8342 }
  let(:binary_tuple) { [described_class::COMMAND, status_code, identifier].pack('CCN') }
  let(:invalid_binary_tuple) { 'totally not the right format' }

  subject(:error_response) { described_class.new(binary_tuple) }

  describe 'decoding' do
    it 'accepts a binary tuple and sets each attribute' do
      expect(error_response.status_code).to eq(status_code)
      expect(error_response.identifier).to eq(identifier)
    end

    it 'raises an exception when there are problems decoding' do
      -> { described_class.new(invalid_binary_tuple) }.should
        raise_error(Grocer::InvalidFormatError)
    end

    it 'finds the status from the status code' do
      expect(error_response.status).to eq('Processing error')
    end
  end

  describe 'false alarm (status of 0)' do
    let(:status_code) { 0 }

    it "should return false_alarm" do
      subject.should be_false_alarm
    end
  end

  describe 'bad token (status of 8)' do
    let(:status_code) { 8 }

    it "should return invalid_token" do
      subject.should be_invalid_token
    end
  end

  it 'accepts a notification' do
    error_response.notification='x'
    expect(error_response.notification).to eq('x')
  end
end
