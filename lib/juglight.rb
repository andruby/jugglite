require "juglight/version"
require "reel"

module Juglight
  class SsePool
    include Celluloid
    include Celluloid::Logger

    def initialize
      @connections = []
    end

    def add_connection(connection)
      @connections << connection
    end

    def broadcast_message(message)
      @connections.each do |out|
        begin
          out << "data: #{message} (#{@connections.count})\n\n"
        rescue Errno::EPIPE
          info "Broken pipe"
          out.close
          @connections.delete(out)
          next
        end
      end
    end
  end

  class WebServer < Reel::Server
    include Celluloid::Logger

    SSE_HEADERS = {
      'Transfer-Encoding' => "chunked",
      'Content-Type' => 'text/event-stream'
    }

    def initialize(host = "127.0.0.1", port = 1234)
      info "Juglight server example starting on #{host}:#{port}"
      @sse_pool = SsePool.new
      super(host, port, &method(:on_connection))
    end

    def on_connection(connection)
      connection.detach
      connection.respond(:ok, SSE_HEADERS, nil)
      @sse_pool.add_connection(connection)
      @sse_pool.broadcast_message!("New Connection!")
    end
  end
end
