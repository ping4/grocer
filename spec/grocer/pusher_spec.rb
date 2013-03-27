require 'spec_helper'
require 'grocer/pusher'

describe Grocer::Pusher do
  let(:connection) { stub_everything }
  let(:notification) { stub(:to_bytes => 'abc123', :identifier= => nil, :identifier => 106) }

  subject { described_class.new(connection) }

  describe '#push' do
    it 'serializes a notification and sends it via the connection' do
      subject.push(notification)

      connection.should have_received(:write).with('abc123')
    end
  end

  describe "with error available" do
    let(:connection) { stub_everything('connection', :can_read? => true, :read_if_connected => [8, 6, 105].pack("ccN")) }
    it "should return errors from read_errors" do
      error=subject.read_errors
      error.should_not be_nil
      error.status_code.should == 6
      error.identifier.should == 105
    end

    describe "with previously sent notifications" do
      let(:prev_notification) { stub(:to_bytes => 'abc123', :identifier= => nil, :identifier => 105) }
      before {
        subject.send(:remember_notification, prev_notification)
      }

      it "should return previous errors" do
        error=subject.push_and_check(notification)
        error.should_not be_nil

        notifications = subject.send(:notification_to_retry, error)
        error.notification.should == prev_notification
        notifications.should == [notification]

        subject.should_not be_remembered_notifications
      end

      it "should clear previous errors" do
        subject.should be_remembered_notifications
        subject.clear_notifications
        subject.should_not be_remembered_notifications
      end
    end
  end

  describe "with no error available" do
    let(:connection) { stub_everything('connection', :can_read? => false) }
    it "should return nothing from read_errors" do
      connection.expects(:read_if_connected).never
      error=subject.read_errors
      error.should be_nil
    end
  end

  context "partial errors" do
    # NOTE: 2 is the identifier we are assuming is assigned to bad_notification.identifier
    it "#resend push for notification errors" do
      # send 1 , 2 , 3, 4, (error on 2 [notifications[1]]), 5 ; resend 3, 4
      connection.expects(:read_if_connected).returns([8, 6, 2].pack('ccN'))
      connection.expects(:can_read?).times(7).then.returns(false).then.returns(false).then.returns(false).then.returns(true).then.returns(false)

      notifications = 5.times.map { |i| Grocer::Notification.new(alert: "alert text #{i}") }

      subject.expects(:push).with(notifications[0]).once
      subject.expects(:push).with(notifications[1]).once
      subject.expects(:push).with(notifications[2]).twice
      subject.expects(:push).with(notifications[3]).twice # first time return error on 2: [1]
      subject.expects(:push).with(notifications[4]).once
      subject.push_and_retry(notifications)
    end
  end

  it "should roll around at max identifier" do
    subject.instance_variable_set(:@identifier, 2001)
    subject.send(:next_identifier).should == 1
  end
end
