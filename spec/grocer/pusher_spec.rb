require 'spec_helper'
require 'grocer/pusher'

describe Grocer::Pusher do
  let(:connection) { stub('connection', write: nil, select: nil, close: nil, connect: nil, read_nonblock: nil) }

  subject { described_class.new(connection) }

  describe '#push' do
    it 'serializes a notification and sends it via the connection' do
      notification = stub(:to_bytes => 'abc123')
      subject.push(notification)

      connection.should have_received(:write).with('abc123')
    end
  end

  context 'delegation' do
    it "#close" do
      subject.close
      connection.should have_received(:close)
    end

    it "#connect" do
      subject.connect
      connection.should have_received(:connect)
    end
  end

  context "with error" do
    it "#read_errors" do
      connection.expects(:select).returns([[connection],[connection]])
      connection.expects(:read_nonblock).returns([8, 6, 105].pack("ccN"))
      connection.expects(:close)
      subject.read_errors.should include(identifier: 105, error_code: 6)
    end
  end

  it "#push_and_check" do
    notification=mock("notification", to_bytes: 'abc')
    subject.push_and_check(notification)
    connection.should have_received(:write).with('abc')
    connection.should have_received(:select)
  end

  it "#resend push for token errors" do
    # send 1 , 2 , 3, 4, (error on 2), 5 ; resend 3, 4

    notifications = 5.times.map { |i| stub(identifier: i, 'identifier=' => nil, 'alert' => 'alert')}
    bad_notification = notifications[1]

    subject.expects(:read_errors).with(nil).at_least_once.returns(
      nil, nil, nil,
      #after sending 4th, return error on 2nd
      { identifier: bad_notification.identifier, error_code: 8 },
      nil, nil, nil, nil
    )
    subject.expects(:read_errors).with(1.0).returns(nil)
    subject.expects(:push).with(notifications[0]).once
    subject.expects(:push).with(notifications[1]).once
    subject.expects(:push).with(notifications[2]).twice
    subject.expects(:push).with(notifications[3]).twice
    subject.expects(:push).with(notifications[4]).once
    subject.push_and_check_batch(notifications)
  end
end
