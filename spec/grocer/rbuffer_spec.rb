require 'spec_helper'
require 'grocer/rbuffer'

describe Grocer::RBuffer do
  describe "empty buffer" do
    subject { tb(5) }
    it "should subject.scan" do
      subject.scan {|i| i == 4 }.should == [nil,[]]
    end
  end

  describe "partially full buffer" do
    subject { tb(5,4) }

    it "should subject.scan first" do
      subject.scan {|i| i == 4 }.should == [4,[]]
    end

    it "should subject.scan middle entry" do
      subject.scan {|i| i == 2 }.should == [2,[4,3]]
    end

    it "should subject.scan last" do
      subject.scan {|i| i == 1 }.should == [1,[4,3,2]]
    end

    it "should subject.scan not found" do
      subject.scan {|i| i == 0 }.should == [nil,[4,3,2,1]]
    end
  end

  describe "full buffer" do
    subject { tb(5,5) }

    it "should subject.scan first" do
      subject.scan {|i| i == 5 }.should == [5,[]]
    end

    it "should subject.scan middle entry" do
      subject.scan {|i| i == 2 }.should == [2,[5,4,3]]
    end

    it "should subject.scan last" do
      subject.scan {|i| i == 1 }.should == [1,[5,4,3,2]]
    end

    it "should subject.scan not found" do
      subject.scan {|i| i == 0 }.should == [nil,[5,4,3,2,1]]
    end
  end

  describe "full buffer + 1 (capacity full)" do
    subject { tb(5,6) }

    it "should subject.scan first" do
      subject.scan {|i| i == 6 }.should == [6,[]]
    end

    it "should subject.scan middle entry" do
      subject.scan {|i| i == 3 }.should == [3,[6,5,4]]
    end

    it "should subject.scan last" do
      subject.scan {|i| i == 2 }.should == [2,[6,5,4,3]]
    end

    it "should subject.scan not found" do
      subject.scan {|i| i == 1 }.should == [nil,[6,5,4,3,2]]
    end
  end

  describe "overflowed buffer" do
    subject { tb(5,7) } # 7,6|5,4,3

    it "should not be empty" do
      subject.should_not be_empty
    end

    it "should subject.scan first" do
      subject.scan {|i| i == 7 }.should == [7,[]]
      subject.should be_empty
    end

    it "should subject.scan mid" do
      subject.scan {|i| i == 4 }.should == [4,[7,6,5]]
      subject.should be_empty
    end

    it "should subject.scan last" do
      subject.scan {|i| i == 3 }.should == [3,[7,6,5,4]]
      subject.should be_empty
    end

    it "should subject.scan not found" do
      subject.scan {|i| i == 2 }.should == [nil,[7,6,5,4,3]]
      subject.should be_empty
    end

    it "should clear buffer after a find" do
      subject.scan {|i| i==7 }
      subject.should be_empty
    end

    it "should have a to_s" do
      subject.to_s.should match(/5/)
    end
  end

  def tb(capacity, num=nil)
    b = Grocer::RBuffer.new(capacity)
    (1..num).each {|i| b.put i } if num
    b
  end
end
