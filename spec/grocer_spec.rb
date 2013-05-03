require 'spec_helper'
require 'grocer'

describe Grocer do
  describe '.env' do
    subject { described_class }
    let(:environment) { nil }
    before do
      ENV.stubs(:[]).with('RAILS_ENV').returns(environment)
      ENV.stubs(:[]).with('RACK_ENV').returns(environment)
    end

    it 'defaults to development' do
      expect(subject.env).to eq('development')
    end

    it 'reads RAILS_ENV from ENV' do
      ENV.stubs(:[]).with('RAILS_ENV').returns('staging')
      expect(subject.env).to eq('staging')
    end

    it 'reads RACK_ENV from ENV' do
      ENV.stubs(:[]).with('RACK_ENV').returns('staging')
      expect(subject.env).to eq('staging')
    end
  end

  describe 'API facade' do
    let(:connection_options) { { certificate: '/path/to/cert.pem' } }

    # describe '.pusher' do
    #   before do
    #     Grocer::PushConnection.stubs(:new).returns(stub('PushConnection'))
    #   end

    #   it 'gets a Pusher' do
    #     expect(subject.pusher(connection_options)).to be_a Grocer::Pusher
    #   end

    #   it 'passes the connection options on to the underlying Connection' do
    #     subject.pusher(connection_options)
    #     Grocer::PushConnection.should have_received(:new).with(connection_options)
    #   end
    # end

    subject { described_class.feedback(connection_options).connection}
    describe '.feedback' do

      it 'can be initialized with a certificate' do
        expect(subject.certificate).to eq('/path/to/cert.pem')
      end

      it 'can be initialized with a passphrase' do
        connection_options[:passphrase] = 'open sesame'
        expect(subject.passphrase).to eq('open sesame')
      end

      it 'defaults to Apple feedback gateway in production environment' do
        Grocer.stubs(:env).returns('production')
        expect(subject.gateway).to eq('feedback.push.apple.com')
      end

      it 'defaults to the sandboxed Apple feedback gateway in development environment' do
        Grocer.stubs(:env).returns('development')
        expect(subject.gateway).to eq('feedback.sandbox.push.apple.com')
      end

      it 'defaults to the sandboxed Apple feedback gateway in test environment' do
        Grocer.stubs(:env).returns('test')
        expect(subject.gateway).to eq('feedback.sandbox.push.apple.com')
      end

      it 'defaults to the sandboxed Apple feedback gateway for other random values' do
        Grocer.stubs(:env).returns('random')
        expect(subject.gateway).to eq('feedback.sandbox.push.apple.com')
      end

      it 'can be initialized with a gateway' do
        connection_options[:gateway] = 'gateway.example.com'
        expect(subject.gateway).to eq('gateway.example.com')
      end

      it 'defaults to 2196 as the port' do
        expect(subject.port).to eq(2196)
      end

      it 'can be initialized with a port' do
        connection_options[:port] = 443
        expect(subject.port).to eq(443)
      end
    end

    describe '.pusher' do
      subject { described_class.pusher(options).connection }
      let(:options) { { certificate: '/path/to/cert.pem' } }
      let(:connection) { stub('Connection') }

      it 'can be initialized with a certificate' do
        expect(subject.certificate).to eq('/path/to/cert.pem')
      end

      it 'can be initialized with a passphrase' do
        options[:passphrase] = 'open sesame'
        expect(subject.passphrase).to eq('open sesame')
      end

      it 'defaults to Apple push gateway in production environment' do
        Grocer.stubs(:env).returns('production')
        expect(subject.gateway).to eq('gateway.push.apple.com')
      end

      it 'defaults to the sandboxed Apple push gateway in development environment' do
        Grocer.stubs(:env).returns('development')
        expect(subject.gateway).to eq('gateway.sandbox.push.apple.com')
      end

      it 'defaults to the localhost Apple push gateway in test environment' do
        Grocer.stubs(:env).returns('test')
        expect(subject.gateway).to eq('127.0.0.1')
      end

      it 'uses a case-insensitive environment to determine the push gateway' do
        Grocer.stubs(:env).returns('TEST')
        expect(subject.gateway).to eq('127.0.0.1')
      end

      it 'defaults to the sandboxed Apple push gateway for other random values' do
        Grocer.stubs(:env).returns('random')
        expect(subject.gateway).to eq('gateway.sandbox.push.apple.com')
      end

      it 'can be initialized with a gateway' do
        options[:gateway] = 'gateway.example.com'
        expect(subject.gateway).to eq('gateway.example.com')
      end

      it 'defaults to 2195 as the port' do
        expect(subject.port).to eq(2195)
      end

      it 'can be initialized with a port' do
        options[:port] = 443
        expect(subject.port).to eq(443)
      end
    end

    describe '.server' do
      subject { described_class }
      let(:ssl_server) { stub_everything('SSLServer') }
      before do
        Grocer::SSLServer.stubs(:new).returns(ssl_server)
      end

      it 'gets Server' do
        expect(subject.server(connection_options)).to be_a Grocer::Server
      end

      it 'passes the connection options on to the underlying SSLServer' do
        subject.server(connection_options)
        Grocer::SSLServer.should have_received(:new).with(connection_options)
      end
    end

    #TODO: ensure defaults for gateway and stuff work
  end
end
