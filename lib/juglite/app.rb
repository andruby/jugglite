require 'set'
require 'em-hiredis'

module Juglite
  # Let's go for plain Rack y'all
  class App
    AsyncResponse = [-1, {}, []].freeze
    Headers = {'Content-Type' => 'text/event-stream;charset=utf-8'}

    # Options include:
    # +path+ : the URI path to listen to ('/stream')
    # +keepalive_timeout+ : the timeout in seconds between keepalive comments
    def initialize(app, options = {})
      @app = app
      @options = options.reverse_merge({
        path: '/stream',
        keepalive_timeout: 20
      })
      STDERR.puts "Registered Juglite to listen to #{@options[:path]}"
      @subscription_map = {}
      EventMachine::next_tick { setup_redis }
      EventMachine::next_tick { setup_keepalive }
    end

    def call(env)
      if env["PATH_INFO"] == @options[:path]
        handle_stream(env)
      else
        @app.call(env)
      end
    end

    private
    def handle_stream(env)
      request = Rack::Request.new(env)
      connection = SseConnection.new(request)

      # Get the headers out there, let the client know we're alive...
      EventMachine::next_tick do
        register_connection(connection)
        # Calling thin's Connection.post_process([status, headers, body])
        # This is how you start a response to the client asynchronously
        env['async.callback'].call [200, Headers, connection.body]
        connection.comment("registered to channels: #{channels_for_request(request).to_a.join(', ')}")
      end

      connection.callback { unregister_connection(connection) }
      connection.errback { unregister_connection(connection) }

      # Needed for crappy Rack::Lint
      throw :async

      # Returning a status of -1 keeps the connection open
      # You need to use env['async.callback'].call to send the status, headers & body later
      AsyncResponse
    end

    def setup_redis
      @redis_channels = Set.new
      @async_redis = EM::Hiredis.connect
      @async_redis.on(:message) do |channel, message|
        expedite_incoming_message(channel, message)
      end
    end

    def setup_keepalive
      EventMachine::add_periodic_timer(@options[:keepalive_timeout]) do
        count = @subscription_map.count
        @subscription_map.each_key do |connection|
          connection.keepalive(count)
        end
      end
    end

    def channels_for_request(request)
      # TODO: Sanitize? Check signature?
      channel = Array(request.params["channel"])
      Set.new(channel)
    end

    def register_connection(connection)
      requested_channels = channels_for_request(connection.request)
      subscribe_to_new_channels(requested_channels - @redis_channels)
      @subscription_map[connection] = requested_channels
    end

    def unregister_connection(connection)
      @subscription_map.delete(connection)
    end

    def subscribe_to_new_channels(channels)
      channels.each do |channel|
        puts "Listening to channel: #{channel}"
        @async_redis.subscribe(channel)
        @redis_channels << channel
      end
    end

    def expedite_incoming_message(channel, message)
      no_connection_listening = true
      # Select upfront and use EM::Iterator
      @subscription_map.each do |connection, channels|
        if channels.include?(channel)
          connection.write message
          no_connection_listening = false
        end
      end
      # We stop listening to a channel whenever a message comes in from a channel
      # which has no associated connections
      # Why? Because clients will disconnect and connect all the time when they load new pages
      # But we don't want to subscribe and unsubscribe from redis all the time.
      if no_connection_listening
        puts "Stop listening to channel: #{channel}"
        @async_redis.unsubscribe(channel)
        @redis_channels.delete(channel)
      end
    end
  end
end
