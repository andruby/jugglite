module Jugglite
  class DeferrableBody
    include EventMachine::Deferrable

    def initialize
      @queue = EM::Queue.new
    end

    def write(body)
      @queue.push(body)
    end

    def each &blk
      @body_callback = blk
      processor = proc { |item|
        @body_callback.call(item)
        @queue.pop(&processor)
      }
      @queue.pop(&processor)
    end
  end
end
