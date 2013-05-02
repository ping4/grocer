require 'spec_helper'
require 'grocer/pusher'
require 'grocer/error_response'
require 'grocer/history'
require 'grocer/notification'

describe Grocer::Pusher do
  let(:connection) { stub('Connection', :read_if_ready => nil) }
  let(:notification) { stub(:to_bytes => 'abc123', :identifier= => nil, identifier: 106, mark_sent: nil) }

  subject { described_class.new(connection) }

  describe 'should write to connection when pushing a notification' do
    it 'pushed_out a notification when pushing' do
      connection.expects(:with_retry).yields(connection)
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
      connection.expects(:read_if_ready).returns([Grocer::ErrorResponse::COMMAND, 6, 105].pack('CCN'))
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
        connection.expects(:read_if_ready).returns([8, 0, 105].pack("ccN"))
        connection.expects(:close)
      end

      it "should return a false alarm from read error (so we can prune history)" do
        subject.read_error.should be_false_alarm
      end

      it "should not have any retries after clarifying the response" do
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
        connection.expects(:with_retry).yields(connection,nil)
        connection.expects(:read_if_ready).returns([8, 6, 105].pack("ccN")).then.returns(nil)
        subject.expects(:push_out)
        connection.stubs(:close)
        error = subject.push(notification)
        error.should_not be_nil

        error.notification.should == prev_notification
        error.resend.should == [notification]

        subject.should_not be_remembered_notifications
      end

      it "should check_and_retry and re-pushes notifications" do
        # first is for the push, second 2 are for check_and_retry
        connection.expects(:with_retry).times(2).yields(connection,nil).then.yields(connection,nil)
        subject.expects(:read_error).times(3).returns(nil).then.returns(error_response(105)).then.returns(nil)
        subject.expects(:push_out).with(notification).twice
        subject.push(notification).should be_nil

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
      connection.expects(:read_if_ready).returns(nil)
    end

    it 'should not return an error and not close the connection' do
      connection.expects(:close).never

      subject.read_error.should be_nil
    end
  end

  it "should inspect" do
    subject.inspect.should match(/Pusher/)
  end

  it "should return errors and change passed in array for push_and_retry" do
    ret2 = []
    ret = subject.push_and_retry([], ret2)
    ret.object_id.should == ret2.object_id
  end

  context "partial errors" do
    # NOTE: 2 is the identifier we are assuming is assigned to bad_notification.identifier
    it "#resend push for notification errors" do
      connection.expects(:with_retry).at_least_once.yields(connection,nil)
      subject.expects(:read_error).times(7).
        then.returns(false). #after 0
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

  context "pusher with forgotten notifications" do
    subject { described_class.new(connection, history_size: 2) }
    it "should not resend notifications if it is not known what went out" do
      connection.expects(:with_retry).at_least_once.yields(connection,nil)
      subject.resend_on_not_found=false
      subject.expects(:read_error).times(4).
        then.returns(false). # after 0 (forgotten)
        then.returns(false). # after 1
        then.returns(false). # after 2
        then.returns(error_response(0)) #after 3

      notifications = 4.times.map { |i| Grocer::Notification.new(alert: "alert text #{i}", identifier: i) }

      subject.expects(:push_out).with(notifications[0]).once
      subject.expects(:push_out).with(notifications[1]).once
      subject.expects(:push_out).with(notifications[2]).once
      subject.expects(:push_out).with(notifications[3]).once
      ret = subject.push_and_retry(notifications)
      ret.should be_kind_of(Array)
      ret.length.should          == 1
      ret[0].notification.should be_nil
      ret[0].resend.should      == [notifications[3], notifications[2]]
    end
    it "should send out notifications if configured to send out notifications" do
      connection.expects(:with_retry).at_least_once.yields(connection,nil)
      subject.resend_on_not_found=true
      subject.expects(:read_error).times(6).
        then.returns(false). # after 0 (forgotten)
        then.returns(false). # after 1 (forgotten)
        then.returns(false). # after 2
        then.returns(error_response(0)). #after 3
        then.returns(false). # after 2
        then.returns(false) # after 3

      notifications = 4.times.map { |i| Grocer::Notification.new(alert: "alert text #{i}", identifier: i) }

      subject.expects(:push_out).with(notifications[0]).once
      subject.expects(:push_out).with(notifications[1]).once
      subject.expects(:push_out).with(notifications[2]).twice
      subject.expects(:push_out).with(notifications[3]).twice
      ret = subject.push_and_retry(notifications)
      ret.should be_kind_of(Array)
      ret.length.should          == 1
      ret[0].notification.should be_nil
      ret[0].resend.should      == [notifications[3], notifications[2]]
    end
  end


  # content "bbg" do
  # end
  context "gbgbgxx" do
    # NOTE: 2 is the identifier we are assuming is assigned to bad_notification.identifier
    it "#resend push for notification errors" do
      connection.expects(:with_retry).at_least_once.yields(connection,nil)
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

  def error_response(identifier)
    Grocer::ErrorResponse.new(identifier)
  end
end
