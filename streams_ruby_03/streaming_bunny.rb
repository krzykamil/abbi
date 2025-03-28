# frozen_string_literal: true

require 'bunny'
require 'uri'

def send_love_letter(msg:)
  sleep 5 # Simulate processing time
  print "sent love letter #{msg} \n"
end

# Access the CLOUDAMQP_URL environment variable and parse it (fallback to localhost)
rabbitmq_url = ENV['CLOUDAMQP_URL'] || 'amqp://guest:guest@localhost:5672/%2f'

connection = Bunny.new(rabbitmq_url)
connection.start
channel = connection.create_channel

# QoS setting is required for streams. Try commenting this before running
channel.basic_qos(2)
# Making a queue into a stream, requires the x-queue-type header argument

consumer = channel.queue('love_letters', durable: true, arguments: {'x-queue-type' => 'stream', })

## Manual Ack
# Stream queues require this explicit acknowledgment because they're designed for high-throughput scenarios where careful message handling is important.
# Uncomment try to publish messages from UI and see if this works
# consumer.subscribe(block: true, manual_ack: true) do |delivery_info, properties, payload|
#   send_love_letter(msg: payload)
#   channel.ack(delivery_info.delivery_tag)
# end

# Alternate syntax due to queue return value
# channel.queue(
#   'love_letters',
#   durable: true,
#   arguments: {'x-queue-type' => 'stream'},
# ).subscribe(block: true, manual_ack: true) do |delivery_info, _properties, payload|
#   send_love_letter(msg: payload)
#
#   channel.ack(delivery_info.delivery_tag)
# end

## Offset
channel.basic_publish('Kocham Cię', '', 'love_letters')
channel.basic_publish('I love you', '', 'love_letters')
channel.basic_publish('Jeg elsker deg', '', 'love_letters')
channel.basic_publish('я тебя люблю', '', 'love_letters')
channel.basic_publish('Ich liebe dich', '', 'love_letters')

puts "Uncomment a publisher in the file to see results if you dont see love letters"

# RabbitMQ Streams can receive and buffer messages even before any consumer is bound.
# When a consumer is eventually bound to such a Stream, it is expected that the Stream will automatically deliver all existing messages to this new consumer.
# At least queues behave that way.
# However, RabbitMQ Streams behave differently. The only messages that would be automatically delivered to a consumer from the Stream it’s bound to are the messages published to the Stream after the consumer starts.
# For example, imagine a Stream, stream_a, that already has one message, message_1. Assume stream_a currently has no consumers bound to it. Five minutes later, however, a new consumer, consumer_a connects to stream_a. Because consumer_a connected after message_1 had already been delivered to stream_a, RabbitMQ won’t automatically deliver message_1 to this new consumer.
# But this begs the question: how can consumer_a grab message_1, an old message?
# By using the message’s offset. For example, if the ID of message_1 or the published timestamp is known, consumer_a can grab it from the Stream by passing the x-stream-offset argument to the basic_consume function as shown in the snippet below.
# Try to experiment with setting different offsets, and see what happens. Publish more messages from UI or just copy more lines to publish
# https://www.rabbitmq.com/docs/streams#consuming

# UNCOMMENT ME
consumer.subscribe(block: true, manual_ack: true, arguments: { 'x-stream-offset': "first" }) do |delivery_info, properties, payload|
  send_love_letter(msg: payload)
  # Stream queues require this explicit acknowledgment because they're designed for high-throughput scenarios where careful message handling is important.
  channel.ack(delivery_info.delivery_tag)
end

# Some other configuration options
# Create a stream queue with a maximum size of 500MB
# Explanation: x-max-length-bytes limits the total size of all segments in the stream.
# When this limit is reached, the oldest segments are discarded to make room for new messages.
# This is useful for controlling disk usage in high-volume systems.
channel.queue(
  'limited_size_stream',
  durable: true,
  arguments: {
    'x-queue-type' => 'stream',
    'x-max-length-bytes' => 524_288_000  # 500MB in bytes
  }
)

# Create a stream queue that retains messages for 7 days
# Explanation: x-max-age defines how long messages are kept in the stream before being discarded.
# Valid time units are D (days), h (hours), m (minutes), s (seconds).
# This helps implement time-based retention policies without manual cleanup.
channel.queue(
  'week_retention_stream',
  durable: true,
  arguments: {
    'x-queue-type' => 'stream',
    'x-max-age' => '7D'  # 7 days retention
  }
)
puts "Created stream queue"

# Explanation: x-stream-max-segment-size-bytes controls the maximum size of individual segment files.
# Smaller segments can improve read performance for specific access patterns but may increase overhead.
# The default is typically 100MB, but this can be tuned based on your workload characteristics.
# Create a stream queue with smaller segment files (10MB each)
channel.queue(
  'small_segment_stream',
  durable: true,
  arguments: {
    'x-queue-type' => 'stream',
    'x-stream-max-segment-size-bytes' => 10_485_760  # 10MB segments
  }
)
puts "Created stream queue"

# Create a stream queue with 3 replicas for high availability
# Explanation: x-initial-cluster-size determines how many replicas of the stream will be maintained across the RabbitMQ cluster.
# Higher values increase fault tolerance but consume more storage.
# This is only applicable in clustered RabbitMQ environments and helps ensure data durability even if some nodes fail.
channel.queue(
  'replicated_stream',
  durable: true,
  arguments: {
    'x-queue-type' => 'stream',
    'x-initial-cluster-size' => 3  # 3 replicas across the cluster
  }
)
puts "Created stream queue"


# Create a production-ready stream with multiple configuration options
# Explanation: This example combines all options to create a production-ready stream queue that balances performance, durability, and resource usage.
# It will retain messages for 30 days or until the 1GB limit is reached, store data in 50MB segments, and maintain 3 replicas for fault tolerance.
channel.queue(
  'production_stream',
  durable: true,
  arguments: {
    'x-queue-type' => 'stream',
    'x-max-length-bytes' => 1_073_741_824,  # 1GB total size
    'x-max-age' => '30D',                   # 30 day retention
    'x-stream-max-segment-size-bytes' => 52_428_800,  # 50MB segments
    'x-initial-cluster-size' => 3           # 3 replicas
  }
)
puts "Created stream queue"


# Close the connection when the script exits
at_exit do
  connection.close
end
