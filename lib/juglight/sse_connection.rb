module Juglight
  class SseConnection
    attr_reader :body

    def initialize(request)
      @request = request
      @body = DeferrableBody.new
    end

    def <<(out)
      @body << out
    end

    def on_close(&block)
      @body.callback(&block)
      @body.errback(&block)
    end

    def close
      @body.succeed
    end
  end
end
