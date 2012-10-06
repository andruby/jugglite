# Will try to open as many connections as possible
# at a rate of about 500 new connections per second.
# Every 2 seconds the script will print out the number of:
# connections triggered, connections that received headers,
# connections failed and connections finished.

# Optional env variables and their defaults:
# HOST: the hostname to connect to (127.0.0.1)
# PORT: the port to connect to (3000)
# RATE: the number of connections per second to open (1000)
# FD_SIZE: try and increase the number of open file descriptors (202400)

# Note: You'll probably need to increase the open file descriptor limit
# for your platform to reach the limits.
# On *nix you can use "ulimit -n XXXXX" to set and "ulimit -n" to read the limit

host = ENV['HOST'] || '127.0.0.1'
port = (ENV['PORT'] || 3000).to_i
$between_time = 1.0 / (ENV['RATE'] || 2000).to_i
file_descriptors = (ENV['FD_SIZE'] || 202400).to_i
$url = "http://#{host}:#{port}/"

require 'eventmachine'
require 'redis'
require 'em-http-request'

new_size = EM.set_descriptor_table_size(file_descriptors)
STDERR.puts "New EventMachine descriptor-table size is #{new_size}"
EM.epoll
EM.kqueue

$trigger_count = 0
$headers_count = 0
$error_count = 0
$finish_count = 0

def connect_to_stream(counter)
  http = EventMachine::HttpRequest.new($url, :inactivity_timeout => 30).get
  http.headers { |hash| $headers_count+= 1 }
  http.callback { |result| $finish_count+= 1 }
  http.errback { |obj| $error_count+=1 }
end

EM.run do
  launch_timer = EventMachine::add_periodic_timer($between_time) do
    connect_to_stream($trigger_count+=1)
  end

  EM::next_tick { $start_time = Time.now } # Set the start time

  monitor_timer = EventMachine::add_periodic_timer(2) do
    secs_elapsed = (Time.now - $start_time).round
    print "#{'%4i' % secs_elapsed} triggered: #{'%6i' % $trigger_count}, "
    print "headered: #{'%6i' % $headers_count}, errors: #{'%6i' % $error_count}, "
    puts  "finish_count: #{'%6i' % $finish_count}"
  end
end
