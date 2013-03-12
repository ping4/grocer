require 'spec_helper'
require 'grocer/pusher'

describe Grocer::Pusher do
  let(:connection) { stub_everything }

  subject { described_class.new(connection) }

  describe '#push' do
    it 'serializes a notification and sends it via the connection' do
      notification = stub(:to_bytes => 'abc123')
      subject.push(notification)

      connection.should have_received(:write).with('abc123')
    end
  end

  context 'delegation' do
    it "#select" do
      subject.select(55)
      connection.should have_received(:select).with(55)
    end

    it "#close" do
      subject.close
      connection.should have_received(:close)
    end
  end
end
