# Juglite

Juglite is a replacement for the incredible [Juggernaut](https://github.com/maccman/juggernaut) by Maccman. It uses [Server Sent Events](http://www.html5rocks.com/en/tutorials/eventsource/basics/) to push events from your application to the client's browser.

## Installation

Add this line to your application's Gemfile:

    gem 'juglite'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install juglite

## Usage

Juglite comes with a binary. This binary runs a thin server that listens on redis for application messages and passes it along to all connected clients.

You can run the binary from any terminal
`juglite`

TODO: Foreman & multiple processes

TODO: Behind nginx so the client connects on one port

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Juglite is licensed under the [MIT license](http://opensource.org/licenses/MIT).
