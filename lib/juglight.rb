require "juglight/version"
require "thin"

new_size = EM.set_descriptor_table_size( 20480 )
STDERR.puts "New descriptor-Table size is #{new_size}"
EM.epoll

module Juglight
  # Let's go for plain Rack y'all
  class DeferrableBody
    include EventMachine::Deferrable

    def initialize
      @queue = []
      # make sure to flush out the queue before closing the connection
      callback {
        puts "Making sure it's clean"
        until @queue.empty?
          @queue.shift.each{|chunk| @body_callback.call(chunk) }
        end
      }
    end

    def schedule_dequeue
      return unless @body_callback
      EventMachine::next_tick do
        next unless body = @queue.shift
        body.each do |chunk|
          @body_callback.call(chunk)
        end
        schedule_dequeue unless @queue.empty?
      end
    end

    def call(body)
      @queue << body
      schedule_dequeue
    end

    def each &blk
      @body_callback = blk
      schedule_dequeue
    end

  end

  class AsyncApp
    AsyncResponse = [-1, {}, []].freeze
    Headers = {'Content-Type' => 'text/event-stream;charset=utf-8'}

    def call(env)
      request = Rack::Request.new(env)
      body = DeferrableBody.new

      # Get the headers out there asap, let the client know we're alive...
      EventMachine::next_tick do
        env['async.callback'].call [200, Headers, body]
      end

      EventMachine::add_timer(0.5) {
        body.call ["cool\n"]
        EventMachine::next_tick {
          # This could actually happen any time, you could spawn off to new
          # threads, pause as a good looking lady walks by, whatever.
          # Just shows off how we can defer chunks of data in the body, you can
          # even call this many times.
          body.call ["Cheers then!"]
          body.succeed
        }
      }

      body.callback { puts "Normal Callback" }
      body.errback { puts "Err Callback" }

      AsyncResponse # May end up in Rack :-)
    end
  end
end
