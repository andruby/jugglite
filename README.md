# Jugglite

[![Build Status](https://secure.travis-ci.org/andruby/jugglite.png?branch=master)](https://travis-ci.org/andruby/jugglite)

Jugglite is a replacement for the incredible [Juggernaut](https://github.com/maccman/juggernaut) by Maccman. It uses [Server Sent Events](http://www.html5rocks.com/en/tutorials/eventsource/basics/) to push events from your application to the client's browser. It uses [Redis](http://www.redis.io) for publish/subscribe and [Thin](http://code.macournoyer.com/thin/) + [EventMachine](https://github.com/eventmachine/eventmachine) to run an evented server that can handle 10K+ concurrent connections.

## Installation

Add this line to your application's Gemfile:

    gem 'jugglite'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jugglite

## Server Usage

I use jugglite as rack middleware in development and as a standalone binary behind nginx in production.

### Stand-alone binary

Jugglite comes with a binary. This binary runs a thin server that listens on redis for application messages and passes it along to all connected clients.

You can run the binary from any terminal like this (these options are the defaults):

`jugglite --address 0.0.0.0 --port 3000 --max-conns 1024`

### As Rack middleware (development)

Add it to your `config.ru` file and make sure your application runs using Thin:

```ruby
require ::File.expand_path('../config/environment',  __FILE__)
# Embed Jugglite when running in development
use Jugglite::App, path: '/stream' if ENV['RACK_ENV'] == 'development'
run MyRails::Application
```

### Behind Nginx (production)

NOTE: because the html5 SSE implementation requires the connection to have the same hostname and port, you'll need to add a reverse proxy in front of your app and jugglite.

This is an example nginx configuration with Unicorn and Jugglite. Make sure you set `proxy_buffering off;` in your Nginx configuration.

```nginx
# Start jugglite with: jugglite --socket /tmp/jugglite.sock
upstream jugglite-example {
  server unix:/tmp/jugglite.sock fail_timeout=0;
}

# Start unicorn with: unicorn --listen /tmp/unicorn.sock --config-file unicorn_conf.rb
upstream unicorn-example {
  server unix:/tmp/unicorn.sock fail_timeout=0;
}

server {
  listen [::]:80 deferred;
  server_name example.com;
  root /var/www/example/current/public;

  # Let Nginx serve assets statically
  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  # Forward /stream to Jugglite and set proxy_buffering off
  location ^~ /stream {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_buffering off;
    proxy_pass http://jugglite-example;
  }

  # Forward all other requests to Unicorn
  try_files $uri/index.html $uri @unicorn;
  location @unicorn {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://unicorn-example;
  }
}
```


## Client Usage

Use the browser's native [Server-Sent Events](http://www.html5rocks.com/en/tutorials/eventsource/basics/) implementation:

```javascript
  es = new EventSource('/stream?channel=yourchannelname');

  es.addEventListener('message', function(e) {
    // Do something with the data
    console.log(e.data);
    // If you JSON encoded the message
    msg = jQuery.parseJSON(e.data);
    }, false);

  es.onopen = function(e) {
    // Connection was opened.
  };

  es.onerror = function(e) {
    if (e.readyState == EventSource.CLOSED) {
      // Connection was closed.
    } else {
      // Some other error?
    };
  };
```

To support older browsers, use [Remy's](http://html5doctor.com/server-sent-events/) excellent [Pollyfill](https://github.com/remy/polyfills/blob/master/EventSource.js). It does revert to ajax long polling for browsers without a native EventSource implementation. Supports almost every old browser (even IE7).

## Sending messages

Use your favorite Redis client to simply publish messages to the channel your clients are subscribing to:

```ruby
redis = Redis.new
redis.publish('yourchannelname', 'This is a message')
# You may want to JSON encode your data
redis.publish('yourchannelname', {hello: 'world', number: 47}.to_json)
```

## Performance

It's been tested on a local machine with the `spec/benchmark/max_connections.rb` spec up to 16K concurrent connections.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Jugglite is licensed under the [MIT license](http://opensource.org/licenses/MIT).
