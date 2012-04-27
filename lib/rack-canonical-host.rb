module Rack # :nodoc:
  class CanonicalHost
    HTML_TEMPLATE = <<-HTML
      <!DOCTYPE html>
      <html lang="en-US">
        <head><title>301 Moved Permanently</title></head>
        <body>
          <h1>Moved Permanently</h1>
          <p>The document has moved <a href="%s">here</a>.</p>
        </body>
      </html>
    HTML

    def initialize(app, host=nil, ignored_paths = [], &block)
      @app = app
      @host = host
      @block = block
      @ignored_paths = ignored_paths
    end

    def call(env)
      if url = url(env)
        [
          301,
          { 'Location' => url, 'Content-Type' => 'text/html' },
          [HTML_TEMPLATE % url]
        ]
      else
        @app.call(env)
      end
    end

    def url(env)
      if (hosts = host(env))
        hosts = [hosts] unless hosts.is_a? Array
        request = Rack::Request.new(env)
        unless hosts.include?(request.host) or @ignored_paths.include?(request.path)
          request.url.sub(%r{\A(https?://)(.*?)(:\d+)?(/|$)}, "\\1#{hosts.first}\\3/")
        end
      end
    end
    private :url

    def host(env)
      @block ? @block.call(env) || @host : @host
    end
    private :host
  end
end
