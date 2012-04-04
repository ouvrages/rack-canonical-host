require 'spec_helper'

require 'rack'
require 'uri'

require 'rack-canonical-host'

describe Rack::CanonicalHost do
  context '#call' do
    let(:requested_uri) { URI.parse('http://myapp.com/test/path') }
    let(:env) { Rack::MockRequest.env_for(requested_uri.to_s) }
    let(:response) { stack(requested_uri.host).call(env) }

    subject { response }

    shared_examples "a non redirected request" do
      it { should_not redirect }

      it 'calls up the stack with the received env' do
        parent_app.should_receive(:call).with(env).and_return(parent_response)
        subject
      end
    end
    
    shared_examples "a redirected request" do
      it { should redirect.via(301) }
      it { should redirect.to('http://new-host.com/test/path') }

      it 'does not call further up the stack' do
        parent_app.should_receive(:call).never
        subject
      end
    end
    
    context 'with a request to a matching host' do
      it_should_behave_like "a non redirected request"

      context 'forwarded' do
        let(:env) { Rack::MockRequest.env_for(requested_uri.path, "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "#{requested_uri.host}") }
        it_should_behave_like "a non redirected request"
      end
    end

    context 'with a request to a non-matching host' do
      let(:response) { stack('new-host.com').call(env) }

      it_should_behave_like "a redirected request"

      context 'forwarded' do
        let(:env) { Rack::MockRequest.env_for(requested_uri.path, "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "#{requested_uri.host}") }
        it_should_behave_like "a redirected request"
      end

    end
    
    context 'with a secondary hostname' do
      let(:secondary_hostname) { 'secondary.com' }
      let(:response) { stack([requested_uri.host, secondary_hostname]).call(env) }

      it_should_behave_like "a non redirected request"
      
      context 'forwarded' do
        let(:env) { Rack::MockRequest.env_for(requested_uri.path, "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "#{requested_uri.host}") }
        it_should_behave_like "a non redirected request"
      end
      
      context 'on secondary' do
        let(:requested_uri) { URI.parse("http://#{secondary_hostname}/test/path") }
        it_should_behave_like "a non redirected request"

        context 'forwarded' do
          let(:env) { Rack::MockRequest.env_for(requested_uri.path, "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "#{requested_uri.host}") }
          it_should_behave_like "a non redirected request"
        end
      end

      context 'on a non matching host' do
        let(:response) { stack(['new-host.com', secondary_hostname]).call(env) }
        it_should_behave_like "a redirected request"
        
        context 'forwarded' do
          let(:env) { Rack::MockRequest.env_for(requested_uri.path, "HTTP_HOST" => "localhost:81", "HTTP_X_FORWARDED_HOST" => "#{requested_uri.host}") }
          it_should_behave_like "a redirected request"
        end
      end
    end
    
    context 'when initialized with a block' do
      let(:block) { Proc.new { |env| "block-host.com" } }
      let(:response) { stack(&block).call(env) }

      context 'with a request to a host matching the block result' do
        let(:requested_uri) { URI.parse('http://block-host.com') }

        it { should_not redirect }

        it 'calls up the stack with the received env' do
          parent_app.should_receive(:call).with(env).and_return(parent_response)
          subject
        end
      end

      context 'with a request host that does not match the block result' do
        let(:requested_uri) { URI.parse('http://block-host.com') }
        let(:env) { Rack::MockRequest.env_for('http://different-host.com/path') }

        it { should redirect.via(301) }
        it { should redirect.to('http://block-host.com/path') }

        it 'does not call further up the stack' do
          parent_app.should_receive(:call).never
          subject
        end
      end
    end
  end


  private


  def parent_response
    [200, {'Content-Type' => 'text/plain'}, 'Success']
  end

  def parent_app
    @parent_app ||= Proc.new { |env| parent_response }
  end

  def stack(host = nil, parent_app = parent_app, &block)
    Rack::Builder.new do
      use Rack::Lint
      use Rack::CanonicalHost, host, &block
      run parent_app
    end
  end
end
