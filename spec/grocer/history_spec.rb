require 'spec_helper'
require 'grocer/history'
require 'grocer/notification'
require 'grocer/error_response'

describe Grocer::History do
  describe "empty buffer" do
    subject { tb(5) }
    it "should subject.scan" do
      test_scan subject, 4, false
    end

    it "should have nuique next_identifier" do
      subject.send(:next_identifier).should_not == subject.send(:next_identifier)
    end

    it "should roll next_identifier when larger than max_identifier" do
      subject.max_identifier = 100
      subject.instance_variable_set(:@identifier, 100)
      subject.send(:next_identifier).should == 1
    end
  end

  describe "single element buffer" do
    subject { tb(5,1) }
    it "should subject.scan first (only 1) (no wrap)" do
      test_scan subject, 1
    end

    it "should know its size" do
      subject.size.should == 1
    end
  end

  describe "partially full buffer" do
    subject { tb(5,4) }

    it "should know its size" do
      subject.size.should == 4
    end

    it "should subject.scan first" do
      test_scan subject, 4
    end

    it "should subject.scan middle entry" do
      test_scan subject, 2, true, [4,3]
    end

    it "should subject.scan last" do
      test_scan subject, 1, true, [4,3,2]
    end

    it "should subject.scan not found" do
      test_scan subject, 0, false, [4,3,2,1]
    end

    it "should clear" do
      subject.clear
      subject.should be_empty
      subject.size.should == 0
    end
  end

  describe "full buffer" do
    subject { tb(5,5) }

    it "should subject.scan first" do
      test_scan subject, 5
    end

    it "should subject.scan middle entry" do
      test_scan subject, 2, true, [5,4,3]
    end

    it "should subject.scan last" do
      test_scan subject, 1, true, [5,4,3,2]
    end

    it "should subject.scan not found" do
      test_scan subject, 0, false, [5,4,3,2,1]
    end
  end

  describe "full buffer + 1 (capacity full)" do
    subject { tb(5,6) }

    it "should subject.scan first" do
      test_scan subject, 6
    end

    it "should subject.scan middle entry" do
      test_scan subject, 3, true, [6,5,4]
    end

    it "should subject.scan last" do
      test_scan subject, 2, true, [6,5,4,3]
    end

    it "should subject.scan not found" do
      test_scan subject, 1, false, [6,5,4,3,2]
    end
  end

  describe "overflowed buffer" do
    subject { tb(5,7) } # 7,6|5,4,3

    it "should not be empty" do
      subject.should_not be_empty
    end

    it "should know its size" do
      subject.size.should == 5
    end

    it "should subject.scan first" do
      test_scan subject, 7, true, []
    end

    it "should subject.scan mid" do
      test_scan subject, 4, true, [7,6,5]
    end

    it "should subject.scan last" do
      test_scan subject, 3, true, [7,6,5,4]
    end

    it "should subject.scan not found" do
      test_scan subject, 2, false, [7,6,5,4,3]
    end
  end

  #create a history record prepopulated with a number of records
  def tb(capacity, num=nil)
    b = Grocer::History.new(size: capacity)
    (1..num).each {|i| b.remember Grocer::Notification.new(alert: i.to_s, identifier: i) } if num
    b
  end

  def test_scan(subject, search_id, found=true, expected_misses=[])

    if found
      notification = subject.history.detect {|n| n && n.identifier == search_id }
      err = error_response(notification.identifier)

      subject.find_culpret(err)#.should == err
      err.notification.should == notification
      err.resend.map(&:alert).should == expected_misses.map(&:to_s)
    else
      err = error_response(999)
      subject.find_culpret(err).should be_nil
      err.notification.should be_nil
      err.resend.map(&:alert).should == expected_misses.map(&:to_s)
    end
    subject.should be_empty
  end

  def error_response(identifier, status_code=8)
    Grocer::ErrorResponse.new([Grocer::ErrorResponse::COMMAND, status_code, identifier].pack('CCN'))
  end
end
