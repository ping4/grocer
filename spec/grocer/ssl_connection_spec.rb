require 'spec_helper'
require 'grocer/ssl_connection'

describe Grocer::SSLConnection do
  def stub_sockets
    TCPSocket.stubs(:new).returns(mock_socket)
    OpenSSL::SSL::SSLSocket.stubs(:new).returns(mock_ssl)
    mock_socket.stubs('setsockopt')
    mock_ssl.stubs('sync=')
  end

  def stub_close
    mock_socket.stubs('close')
    mock_ssl.stubs('close')
  end

  def stub_certificate
    example_data = File.read(File.dirname(__FILE__) + '/../fixtures/example.pem')
    File.stubs(:read).with(connection_options[:certificate]).returns(example_data)
  end

  let(:mock_socket) { stub('Socket', setsockopt: nil) }
  let(:mock_ssl)    { stub('SSLSocket', :sync= => nil, connect: nil) }

  let(:connection_options) {
    {
      certificate: '/path/to/cert.pem',
      gateway:     'gateway.push.example.com',
      port:         1234
    }
  }

  subject { described_class.new(connection_options) }

  describe 'configuration with pre-read certificate' do
    before do
      stub_certificate
    end

    subject {
      string_io = File.read(connection_options[:certificate])
      described_class.new(connection_options.merge(certificate: string_io))
    }

    it 'is initialized with a certificate IO' do
      expect(subject.certificate).to eq(File.read(connection_options[:certificate]))
    end
  end

  describe 'configuration with a file certificate' do
    before do
      stub_sockets
      connection_options[:certificate] = File.new(File.dirname(__FILE__) + '/../fixtures/example.pem')
    end
    it 'uses the file to load the certificate' do
      OpenSSL::X509::Certificate.expects(:new).with(File.read(File.dirname(__FILE__) + '/../fixtures/example.pem'))
      subject.connect
    end
  end

  describe 'configuration' do
    it 'is initialized with a certificate' do
      expect(subject.certificate).to eq(connection_options[:certificate])
    end

    it 'is initialized with a passphrase' do
      connection_options[:passphrase] = 'new england clam chowder'
      expect(subject.passphrase).to eq(connection_options[:passphrase])
    end

    it 'defaults to an empty passphrase' do
      expect(subject.passphrase).to be_nil
    end

    it 'is initialized with a gateway' do
      expect(subject.gateway).to eq(connection_options[:gateway])
    end

    it 'requires a gateway' do
      connection_options.delete(:gateway)
      -> { described_class.new(connection_options) }.should raise_error(Grocer::NoGatewayError)
    end

    it 'is initialized with a port' do
      expect(subject.port).to eq(connection_options[:port])
    end

    it 'requires a port' do
      connection_options.delete(:port)
      -> { described_class.new(connection_options) }.should raise_error(Grocer::NoPortError)
    end
  end

  describe 'connecting' do
    before do
      stub_sockets
      stub_certificate
    end

    it 'sets up an socket connection' do
      subject.connect
      TCPSocket.should have_received(:new).with(connection_options[:gateway],
                                                connection_options[:port])
    end

    it 'sets up an SSL connection' do
      subject.connect
      OpenSSL::SSL::SSLSocket.should have_received(:new).with(mock_socket, anything)
    end

    it 'reconnects' do
      mock_ssl.expects(:close)
      mock_socket.expects(:close)
      #make sure they are available
      subject.connect

      subject.reconnect
      #calls close

      #calls connect twice: once for subject.connect and a second time for the subject.reconnect
      OpenSSL::SSL::SSLSocket.should have_received(:new).with(mock_socket, anything).twice
    end

    it "should not connect if already connected" do
      subject.expects(:connected?).at_least_once.returns(true)
      subject.connect
      OpenSSL::SSL::SSLSocket.should have_received(:new).never
    end

    it '#write connects SSLConnection and delegates to it' do
      mock_ssl.expects(:connect)
      mock_ssl.expects(:write).with('Apples to Oranges')

      subject.with_retry do |connection|
        connection.write('Apples to Oranges')
      end
    end
  end

  describe 'connected socket' do
    before do
      stub_sockets
      stub_certificate
      subject.connect
    end

    it 'should writes to the SSL connection' do
      mock_ssl.expects(:write).with('abc123')
      subject.write('abc123')
    end

    it 'should read from the SSL connection' do
      mock_ssl.expects(:read).with(42)
      subject.read(42)
    end

    it 'should be ready with no timeout' do
      subject.ready?(nil).should be_true
    end

    it 'should read with no blocking' do
      IO.expects(:select).returns([[mock_ssl],[],[]])
      subject.ready?(0).should be_true
    end

    it 'should not read with no blocking and no data' do
      IO.expects(:select).returns([],[],[])
      subject.ready?(0).should be_false
    end

    it '#write delegates to SSLConnection through #with_retry' do
      mock_ssl.expects(:write).with('Apples to Oranges')
      subject.with_retry { |c,e| c.write('Apples to Oranges') }
    end

    it 'raises CertificateExpiredError for OpenSSL::SSL::SSLError with /certificate expired/i message' do
      mock_ssl.expects(:write).raises(OpenSSL::SSL::SSLError.new('certificate expired'))
      -> {
        subject.with_retry do |c|
          c.write('abc123')
        end
      }.should raise_error(Grocer::CertificateExpiredError)
    end
  end

  describe 'retries' do
    before do
      stub_sockets
      stub_certificate
      subject.connect
      stub_close #expects?
    end

    [SocketError, OpenSSL::SSL::SSLError, Errno::EPIPE].each do |error|
      it "retries #write in the case of an #{error}" do
        mock_ssl.expects(:write).twice.raises(error).then.returns(42)
        subject.with_retry do |connection|
          connection.write('abc123')
        end
      end

      it 'allows user to define own retry logic/count' do
        mock_ssl.expects(:write).times(3).raises(error).then.raises(error).then.returns(42)

        subject.with_retry do |connection, exception|
          if connection
            connection.write('abc123')
          else
            true
          end
        end
      end

      it 'raises the error if none of the retries work' do
        mock_ssl.expects(:write).times(3).raises(error)
        -> {
          subject.with_retry do |connection|
            connection.write('abc123')
          end
        }.should raise_error(error)
      end

      it 'raises the error if none of the retries work' do
        mock_ssl.expects(:write).raises(error).then.raises(error)
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

    it "clears the connection between retries" do
      mock_ssl.expects(:write).twice.raises(Errno::EPIPE).then.returns(42)
      subject.with_retry do |connection|
        connection.write('abc123')
      end
    end
  end
end
