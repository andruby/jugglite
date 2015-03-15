require 'set'
require 'em-hiredis'

module Jugglite
  # Let's go for plain Rack y'all
  class App
    AsyncResponse = [-1, {}, []].freeze
    Headers = {
      'Content-Type' => 'text/event-stream;charset=utf-8',
      'Cache-Control' => 'no-cache' # IE (through the Polyfill) will trip without this
    }

    # Options include:
    # +path+ : the URI path to listen to (defaults to '/stream')
    # +keepalive_timeout+ : the timeout in seconds between keepalive comments (defaults to 20)
    # +namespace+ : a namespace used as prefix for redis pubsub channels
    # +allowed_channels+ :
    #  * an array with allowed channel names
    #  * a proc that takes a Rack::Request and returns an array of allowed channels for that particular request
    # +on_register+ : a Proc that takes a Sse::Connection as argument and is called right after a connection is initiated.
    # +on_unregister+ : a Proc that takes a Sse::Connection as argument and is called right after a connection is initiated.
    # The same Sse::Connection object will be passed to the on_register and on_unregister callbacks. You can for example use the +connection.data+ attribute to store an identifier.
    def initialize(app = nil, options = {})
      @app = app
      @options = {
        path: '/stream',
        namespace: '',
        keepalive_timeout: 20
      }.merge(options)
      @subscription_map = {}
      EventMachine::next_tick { setup_redis }
      EventMachine::next_tick { setup_keepalive }
    end

    def call(env)
      if @app.nil? || (env["PATH_INFO"] == @options[:path])
        handle_stream(env)
      else
        # Running as middleware and path did not match so pass it along
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

      # Needed for Rack::Lint
      throw :async

      # Returning a status of -1 keeps the connection open
      # You need to use env['async.callback'].call to send the status, headers & body later
      AsyncResponse
    end

    def setup_redis
      @redis_channels = Set.new
      @async_redis = EM::Hiredis.connect.pubsub
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
      channel_string = request.params["channel"] || ""
      channels = Array(channel_string.split(","))
      # Sanitize channels
      channels = channels & allowed_channels(request) if @options[:allowed_channels]
      channels.map! { |channel| @options[:namespace] + channel }
      Set.new(channels)
    end

    def allowed_channels(request)
      case @options[:allowed_channels]
      when Proc then @options[:allowed_channels].call(request)
      when Array then @options[:allowed_channels]
      else raise(ArgumentError, ":allowed_channels should be nil, Array or a Proc")
      end
    end

    def register_connection(connection)
      requested_channels = channels_for_request(connection.request)
      subscribe_to_new_channels(requested_channels - @redis_channels)
      @options[:on_register].call(connection) if @options[:on_register]
      @subscription_map[connection] = requested_channels
    end

    def unregister_connection(connection)
      @options[:on_unregister].call(connection) if @options[:on_register]
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
      options = extract_options_from_message(message)
      # Select upfront and use EM::Iterator
      @subscription_map.each do |connection, channels|
        if channels.include?(channel)
          connection.write message, options
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

    def extract_options_from_message(message)
      data = JSON.parse(message)
      options = {}
      options['event'] = data.delete('event') if data['event']
      options['id'] = data.delete('id') if data['id']
      options
    rescue JSON::ParserError
      # The message is not valid json, so we are not able to extract options
      {}
    end
  end
end
