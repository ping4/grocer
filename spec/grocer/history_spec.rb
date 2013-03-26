require 'spec_helper'
require 'grocer/history'

describe Grocer::History do
  describe "empty buffer" do
    subject { tb(5) }
    it "should subject.scan" do
      test_scan subject, 4, false
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
    (1..num).each {|i| b.remember i } if num
    b
  end

  def test_scan(subject, search_id, found=true, expected_misses=[])
    expected_id = found ? search_id : nil

    misses=[]
    subject.find_culpret(misses) {|i| i == search_id }.should == expected_id
    misses.should == expected_misses
    subject.should be_empty
  end
end
