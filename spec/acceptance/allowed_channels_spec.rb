require 'spec_helper'
require 'net/http'

def start_server(jugglite)
  @app = nil
  @thread = Thread.new do
    @app = Thin::Server.new(@host, @port, jugglite)
    @app.start
  end
  sleep(0.01) until @app && @app.running?
end

def stop_server
  @app.stop!
  @thread.join
end

describe "allowed_channels" do
  before(:each) do
    @host = '127.0.0.1'
    @port = rand(10000)+10000
    @channel1 = "randomized:test:#{rand(2**32)}"
    @channel2 = "randomized:test:#{rand(2**32)}"
  end

  after(:each) do
    stop_server
  end

  describe "as an array" do
    before(:each) do
      @jugglite = Jugglite::App.new(nil, allowed_channels: [@channel1])
      start_server(@jugglite)
    end

    it "should only registers to channel 1" do
      Net::HTTP.start(@host, @port) do |http|
        request = Net::HTTP::Get.new("/?channel=#{@channel1},#{@channel2}")

        body = ""
        http.request(request) do |response|
          response.read_body do |chunk|
            body << chunk
            body.should include(": registered to channels: #{@channel1}")
            body.should_not include(@channel2)
            http.finish
            break
          end
          break
        end
      end
    end
  end

  describe "no channel" do
    before(:each) do
      @jugglite = Jugglite::App.new(nil, allowed_channels: ->(request) { [@channel2] })
      start_server(@jugglite)
    end

    it "allows blank channel" do
      Net::HTTP.start(@host, @port) do |http|
        request = Net::HTTP::Get.new("/")

        body = ""
        http.request(request) do |response|
          response.read_body do |chunk|
            body << chunk
            body.should include(": registered to channels: ")
            body.should_not include(@channel1)
            http.finish
            break
          end
          break
        end
      end
    end
  end

  describe "as a Proc" do
    before(:each) do
      @jugglite = Jugglite::App.new(nil, allowed_channels: ->(request) { [@channel2] })
      start_server(@jugglite)
    end

    it "should only registers to channel 2" do
      Net::HTTP.start(@host, @port) do |http|
        request = Net::HTTP::Get.new("/?channel=#{@channel1},#{@channel2}")

        body = ""
        http.request(request) do |response|
          response.read_body do |chunk|
            body << chunk
            body.should include(": registered to channels: #{@channel2}")
            body.should_not include(@channel1)
            http.finish
            break
          end
          break
        end
      end
    end
  end
end
