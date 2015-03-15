module Jugglite
  class SseConnection
    attr_reader :body, :request

    # +data+ can hold optional information to track a connection
    attr_accessor :data

    def initialize(request)
      @request = request
      @longpolling = request.xhr?
      @body = DeferrableBody.new
    end

    def longpolling?
      @longpolling
    end

    def write(message, options = {})
      reset_timeout if longpolling?
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

    private
    def reset_timeout
      # From http://html5doctor.com/server-sent-events/#using-the-polyfill
      @timeout.cancel if @timeout
      @timeout = EventMachine::Timer.new(0.25) do
        self.close
      end
    end
  end
end
