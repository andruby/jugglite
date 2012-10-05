module Juglight
  class SseConnection
    attr_reader :body, :request

    def initialize(request)
      @request = request
      @body = DeferrableBody.new
    end

    def write(message, options = {})
      options.each do |k,v|
        @body << "#{k}: #{v}\n"
      end
      @body << "data: #{message}\n\n"
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
