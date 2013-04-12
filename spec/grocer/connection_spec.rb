require 'spec_helper'
require 'grocer/connection'

describe Grocer::Connection do
  subject { described_class.new(connection_options) }
  let(:connection_options) { { certificate: '/path/to/cert.pem',
                               gateway: 'push.example.com',
                               port: 443 } }
  let(:ssl) { stub('SSLConnection', connect: nil, new: nil, write: nil, read: nil, close: nil) }
  before do
    Grocer::SSLConnection.stubs(:new).returns(ssl)
  end

  it 'can open the connection to the apple push notification service' do
    subject.connect
    ssl.should have_received(:connect)
  end

  it 'raises CertificateExpiredError for OpenSSL::SSL::SSLError with /certificate expired/i message' do
    ssl.stubs(:write).raises(OpenSSL::SSL::SSLError.new('certificate expired'))
    -> {
      subject.with_retry do |c|
        c.write('abc123')
      end
    }.should raise_error(Grocer::CertificateExpiredError)
  end

  context 'an open SSLConnection' do
    before do
      ssl.stubs(:connected?).returns(true)
    end

    it '#write delegates to open SSLConnection' do
      subject.write('Apples to Oranges')
      ssl.should have_received(:write).with('Apples to Oranges')
    end

    it '#write delegates to open SSLConnection through with_retry' do
      subject.with_retry { |c,e| c.write('Apples to Oranges') }
      ssl.should have_received(:write).with('Apples to Oranges')
    end

    it '#read delegates to open SSLConnection' do
      ssl.expects(:read).with(42)
      subject.read(42)
    end

    it '#ready delegates to open SSLConnection' do
      ssl.expects(:ready?)
      subject.ready?
    end

    it "#close delegates to ssl connection" do
      subject.close
      ssl.should have_received(:close)
    end
  end

  context 'a closed SSLConnection' do
    before do
      ssl.stubs(:connected?).returns(false)
    end

    it '#write connects SSLConnection and delegates to it' do
      subject.with_retry do |connection|
        connection.write('Apples to Oranges')
      end
      ssl.should have_received(:connect)
      ssl.should have_received(:write).with('Apples to Oranges')
    end
  end

  describe 'retries' do
    [SocketError, OpenSSL::SSL::SSLError, Errno::EPIPE].each do |error|
      it "retries #write in the case of an #{error}" do
        ssl.expects(:write).raises(error).then.returns(42)
        subject.with_retry do |connection|
          connection.write('abc123')
        end
      end

      it 'allows user to define own retry logic/count' do
        ssl.expects(:write).times(3).raises(error).then.raises(error).then.returns(42)

        subject.with_retry do |connection, exception|
          if connection
            connection.write('abc123')
          else
            true
          end
        end
      end

      it 'raises the error if none of the retries work' do
        connection_options[:retries] = 1
        ssl.stubs(:write).raises(error).then.raises(error)
        -> {
          subject.with_retry do |connection, exception|
            if connection
              connection.write('abc123')
            else
              false
            end
          end
        }.should raise_error(error)
      end
    end
  end

  it "clears the connection between retries" do
    ssl.stubs(:write).raises(Errno::EPIPE).then.returns(42)
    subject.with_retry do |connection, exception|
      if connection
        connection.write('abc123')
      else
        true
      end
    end
    ssl.should have_received(:close)
  end
end
