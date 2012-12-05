require 'spec_helper'
require 'net/http'

# Execute a GET request for +channel+ that reads the body in chunks
# until the +regexp+ is received or +timeout+ seconds have passed
# def listen_on_channel_until(channel, regexp, timeout = 5)
#   Net::HTTP.start(@host, @port) do |http|
#       request = Net::HTTP::Get.new("/?channel=#{@channel}")

#       body = ""
#       http.request(request) do |response|
#         start_time = Time.now
#         response.read_body do |chunk|
#           body << chunk
#           body.should include(": registered to channels: #{@channel}")
#           http.finish
#           break
#         end
#         break
#       end
#     end
# end

describe "Streaming and publishing" do
  before(:all) do
    @host = '127.0.0.1'
    @port = rand(10000)+10000
    @channel = "randomized:test:#{rand(2**32)}"
    @app = nil
    @thread = Thread.new do
      @app = Thin::Server.new(@host, @port, Jugglite::App.new)
      @app.start
    end
    sleep(0.01) until @app && @app.running?
  end

  after(:all) do
    @app.stop!
    @thread.join
  end

  it "should keep a GET open" do
    Net::HTTP.start(@host, @port) do |http|
      request = Net::HTTP::Get.new("/?channel=#{@channel}")

      body = ""
      http.request(request) do |response|
        response.read_body do |chunk|
          body << chunk
          body.should include(": registered to channels: #{@channel}")
          http.finish
          break
        end
        break
      end
    end
  end
end
