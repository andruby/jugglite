module Juglight
  class DeferrableBody
    include EventMachine::Deferrable

    def initialize
      @queue = []
      # make sure to flush out the queue before closing the connection
    end

    def schedule_dequeue
      return unless @body_callback
      EventMachine::next_tick do
        next unless body = @queue.shift
        @body_callback.call(body)
        schedule_dequeue unless @queue.empty?
      end
    end

    def <<(body)
      @queue << body
      schedule_dequeue
    end

    def each &blk
      @body_callback = blk
      schedule_dequeue
    end

  end
end
