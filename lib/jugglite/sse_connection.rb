module Jugglite
  class SseConnection
    attr_reader :body, :request

    def initialize(request)
      @request = request
      @body = DeferrableBody.new
    end

    def write(message, options = {})
      buffer = ""
      options.each { |k, v| buffer << "#{k}: #{v}\n" }
      message.each_line { |line| buffer << "data: #{line.strip}\n" }
      @body.write(buffer << "\n")
    end

    def keepalive(extra=nil)
      # From http://dev.w3.org/html5/eventsource/#notes
      comment("keepalive #{extra}")
    end

    def comment(comment)
      @body.write(": #{comment}\n")
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
