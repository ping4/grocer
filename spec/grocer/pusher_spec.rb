require 'spec_helper'
require 'grocer/pusher'

describe Grocer::Pusher do
  let(:connection) { stub('Connection') }

  subject { described_class.new(connection) }

  describe '#push' do
    it 'serializes a notification and sends it via the connection' do
      connection.expects(:write).with('abc123')
      notification = stub(to_bytes: 'abc123', write: nil)
      subject.push(notification)

    end
  end
end
