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

    it "#connect" do
      subject.connect
      connection.should have_received(:connect)
    end
  end

  context "with error" do
    it "#read_errors" do
      connection.expects(:gets).returns([8, 6, 105].pack("ccN"))
      subject.read_error.should == {identifier: 105, error_code: 6}
    end

    it "#read_errors" do
      connection.expects(:select).returns([[connection],[connection]])
      # return 1 error, then nil
      connection.expects(:gets).twice.returns(
        [8, 6, 105].pack("ccN"),
        nil
      )
      connection.expects(:close)
      subject.read_errors.should == [{identifier: 105, error_code: 6}]
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

    notifications = 5.times.map { |i| stub(identifier: i, '[]=' => nil)}
    bad_notification = notifications[1]

    subject.stubs(:push) #.exactly(7).times

    subject.stubs(:read_errors).returns(
      nil, nil, nil,
      #after sending 4th, return error on 2nd
      { identifier: bad_notification.identifier, error_code: 8 },
      nil, nil, nil, nil
    )
    subject.expects(:push).with(notifications[0]).once
    subject.expects(:push).with(notifications[1]).once
    subject.expects(:push).with(notifications[2]).twice
    subject.expects(:push).with(notifications[3]).twice
    subject.expects(:push).with(notifications[4]).once

    subject.push_and_check_batch(notifications)
  end
end
