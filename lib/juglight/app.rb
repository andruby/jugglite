module Juglight
  # Let's go for plain Rack y'all
  class App
    AsyncResponse = [-1, {}, []].freeze
    Headers = {'Content-Type' => 'text/event-stream;charset=utf-8'}

    def initialize()
      @subscription_map = {}
    end

    def call(env)
      request = Rack::Request.new(env)
      connection = SseConnection.new(request)
      requested_channels = get_channels_from_request(request)
      register_subscriptions(connection, requested_channels)

      # Get the headers out there asap, let the client know we're alive...
      EventMachine::next_tick do
        # Calling thin's Connection.post_process([status, headers, body])
        # This is how you start a response to the client asynchronously
        env['async.callback'].call [200, Headers, connection.body]
        connection << "Pipe through connections\n"
      end

      EventMachine::add_timer(0.5) {
        connection << "cool\n"
        EventMachine::next_tick {
          # This could actually happen any time, you could spawn off to new
          # threads, pause as a good looking lady walks by, whatever.
          # Just shows off how we can defer chunks of data in the body, you can
          # even call this many times.
          connection << "Cheers then\n"
          EventMachine::next_tick { connection.close }
        }
      }

      connection.on_close { puts "Normal Callback" }

      # Returning a status of -1 keeps the connection open
      # You need to use env['async.callback'].call to send the status, headers & body later
      AsyncResponse
    end

    private
    def get_channels_from_request(request)
      ["broadcast", "private"]
    end

    def register_subscriptions(connection, channels)
      @subscription_map[connection] = channels
    end
  end
end
