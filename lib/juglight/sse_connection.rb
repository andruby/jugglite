module Juglight
  class SseConnection
    attr_reader :body, :request

    def initialize(request)
      @request = request
      @body = DeferrableBody.new
    end

    def write(message, options = {})
      buffer = ""
      options.each do |k, v|
        buffer << "#{k}: #{v}\n"
      end
      message.each_line do |line|
        buffer << "data: #{line.strip}\n"
      end
      @body.write(buffer << "\n")
    end

    def keepalive
      # From http://dev.w3.org/html5/eventsource/#notes
      @body.write(": keepalive\n")
    end

    def close
      @body.succeed
    end

    def callback(&block)
      @body.callback(&block)
    end

    def errback(&block)
      @body.errback(&block)
    end
  end
end
