require 'spec_helper'
require 'grocer/pusher'
require 'grocer/error_response'

describe Grocer::Pusher do
  let(:connection) { stub('Connection') }

  subject { described_class.new(connection) }

  describe 'should write to connection when pushing a notification' do
    it 'serializes a notification and sends it via the connection' do
      connection.expects(:write).with('abc123')
      notification = stub(to_bytes: 'abc123')
      subject.push(notification)
    end
  end

  describe 'with an error' do
    before do
      connection.expects(:read_with_timeout).returns([Grocer::ErrorResponse::COMMAND, 8, 10].pack('CCN'))
    end

    it 'should close the connection and return an error' do
      connection.expects(:close)

      subject.read_error.should be_kind_of(Grocer::ErrorResponse)
    end
  end

  describe 'without an error' do
    before do
      connection.expects(:read_with_timeout).returns(nil)
    end

    it 'should not return an error and not close the connection' do
      connection.expects(:close).never

      subject.read_error.should be_nil
    end
  end

  it "should inspect" do
    subject.inspect.should match(/Pusher/)
  end
end
