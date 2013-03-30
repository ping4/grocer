require 'spec_helper'
require 'grocer/pusher'
require 'grocer/error_response'
require 'grocer/history'
require 'grocer/notification'

describe Grocer::Pusher do
  let(:connection) { stub('Connection') }
  let(:notification) { stub(:to_bytes => 'abc123', :identifier= => nil, identifier: 106, mark_sent: nil) }

  subject { described_class.new(connection) }

  describe 'should write to connection when pushing a notification' do
    it 'pushed_out a notification when pushing' do
      subject.expects(:push_out).with(notification)
      subject.push(notification)
    end

    it 'serializes a notification and sends it via the connection' do
      connection.expects(:write).with('abc123')
      notification = stub(to_bytes: 'abc123')
      subject.send(:push_out, notification)
    end
  end

  describe "with error available" do
    it "should return an error from read_error" do
      connection.expects(:read_with_timeout).returns([Grocer::ErrorResponse::COMMAND, 6, 105].pack('CCN'))
      connection.expects(:close)

      error=subject.read_error
      error.should_not be_nil
      error.status_code.should == 6
      error.identifier.should == 105
    end

    describe "with a false alarm" do
      let(:prev_notification) { stub(to_bytes: 'abc123', :identifier= => 105, identifier: 105) }

      before do
        subject.send(:remember_notification, prev_notification) #this is one that is causing the error
        connection.expects(:read_with_timeout).returns([8, 0, 105].pack("ccN"))
        connection.expects(:close)
      end

      it "should return a false alarm from read error (so we can prune history)" do
        subject.read_error.should be_false_alarm
      end

      it "should not have any retries from read_error_and_history" do
        subject.read_error_and_history.resend.should be_nil
        subject.should_not be_remembered_notifications
      end

      it "should not retry any notifications" do
        subject.expects(:push_and_retry).never
        subject.check_and_retry.should be_empty
      end
    end

    describe "with previously sent notifications" do
      let(:prev_notification) { stub(to_bytes: 'abc123', :identifier= => 105, identifier: 105) }
      before do
        subject.send(:remember_notification, prev_notification) #this is one that is causing the error
      end

      it "should return previous errors" do
        connection.expects(:read_with_timeout).returns([8, 6, 105].pack("ccN")).then.returns(nil)
        subject.expects(:push_out)
        connection.stubs(:close)
        subject.push(notification)
        error=subject.read_error_and_history
        error.should_not be_nil

        error.notification.should == prev_notification
        error.resend.should == [notification]

        subject.should_not be_remembered_notifications
      end

      it "should check_and_retry and re-pushes notifications" do
        subject.expects(:read_error).times(2).returns(error_response(105)).then.returns(nil)
        subject.expects(:push_out).with(notification).twice
        subject.push(notification)

        error=subject.check_and_retry
        error.should_not be_empty
      end

      it "should clear previous errors" do
        subject.should be_remembered_notifications
        subject.clear_notifications
        subject.should_not be_remembered_notifications
      end
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

  context "partial errors" do
    # NOTE: 2 is the identifier we are assuming is assigned to bad_notification.identifier
    it "#resend push for notification errors" do
      subject.expects(:read_error).times(7).returns(false). #after 0
        then.returns(false). # after 1
        then.returns(false). # after 2
        then.returns(error_response(1)). #after 3
        then.returns(false) #fter 3, 2, 5

      notifications = 5.times.map { |i| Grocer::Notification.new(alert: "alert text #{i}", identifier: i) }

      subject.expects(:push_out).with(notifications[0]).once
      subject.expects(:push_out).with(notifications[1]).once
      subject.expects(:push_out).with(notifications[2]).twice
      subject.expects(:push_out).with(notifications[3]).twice # first time return error on 2: [1]
      subject.expects(:push_out).with(notifications[4]).once
      ret = subject.push_and_retry(notifications)
      ret.should be_kind_of(Array)
      ret.length.should          == 1
      ret[0].notification.should == notifications[1]
      ret[0].resend.should      == [notifications[3], notifications[2]]
    end
  end

  # content "bbg" do
  # end
  context "gbgbgxx" do
    # NOTE: 2 is the identifier we are assuming is assigned to bad_notification.identifier
    it "#resend push for notification errors" do
      subject.expects(:read_error).times(9).returns(false). #0
        then.returns(false). #1
        then.returns(false). #2 - dropped
        then.returns(error_response(1)). #3 - dropped
        then.returns(false). #3
        then.returns(false). #2 - dropped
        then.returns(error_response(3)). #4 - dropped
        then.returns(false) #4, #2

      notifications = 5.times.map { |i| Grocer::Notification.new(alert: "alert text #{i}", identifier: i) }

      subject.expects(:push_out).with(notifications[0]).once
      subject.expects(:push_out).with(notifications[1]).once
      subject.expects(:push_out).with(notifications[2]).times(3)
      subject.expects(:push_out).with(notifications[3]).twice
      subject.expects(:push_out).with(notifications[4]).twice
      ret = subject.push_and_retry(notifications)
      ret.should be_kind_of(Array)
      ret.length.should          == 2
      ret[0].notification.should == notifications[1]
      ret[0].resend.should      == [notifications[3], notifications[2]]
      ret[1].notification.should == notifications[3]
      ret[1].resend.should      == [notifications[4], notifications[2]]
    end
  end

  def error_response(identifier, status_code=8)
    Grocer::ErrorResponse.new([Grocer::ErrorResponse::COMMAND, status_code, identifier].pack('CCN'))
  end
end
