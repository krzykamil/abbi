# frozen_string_literal: true

# The RabbitMQ prefetch value is used to specify how many messages are being sent at the same time.
# As explained in GLOSSARY, by default, RabbitMQ sends as many messages as it can to any consumer that appears ready to accept them.
# Messages are cached by the RabbitMQ client library (in the consumer) until processed.
# All pre-fetched messages are invisible to other consumers and are listed as unacked messages in the RabbitMQ management interface.
#
# An unlimited buffer of messages sent from the broker to the consumer could lead to a window of many unacknowledged messages.
# Prefetching in RabbitMQ simply allows you to set a limit of the number of unacked (not handled) messages.

require 'bunny'
require 'thread'


def run_test(test_name, prefetch_count = nil, global = true)
  puts "\n\n" + "="*50
  puts "STARTING TEST: #{test_name}"
  puts "="*50

  rabbitmq_url = ENV['CLOUDAMQP_URL'] || 'amqp://guest:guest@localhost:5672/%2f'
  connection = Bunny.new(rabbitmq_url)
  connection.start
  channel = connection.create_channel

  if prefetch_count
    global_text = global ? "global (channel-wide)" : "per-consumer"
    puts "Setting prefetch to #{prefetch_count} (#{global_text})"
    channel.prefetch(prefetch_count, global: global)
  else
    puts "No prefetch limit set (default RabbitMQ behavior)"
  end

  queue_name = "task_queue_#{rand(1000)}"
  queue = channel.queue(queue_name, durable: true)

  # Tracking variables. Maybe add some more things to track?
  mutex = Mutex.new
  unacked_count = 0
  max_unacked = 0
  total_received = 0
  received_timestamps = []

  # Start acknowledging in a separate thread after a delay
  ack_thread = Thread.new do
    # Wait to let messages accumulate first
    sleep 3

    puts "\nStarting to acknowledge messages..."
    # Process all messages that will be received
    while total_received < 10
      if unacked_count > 0
        mutex.synchronize do
          # Acknowledge oldest message
          channel.ack(received_timestamps.first[:tag])
          received_timestamps.shift
          unacked_count -= 1
          puts "Acknowledged a message (#{unacked_count} unacked remaining)"
        end
      end
      sleep 0.5
    end
  end

  # Consumer
  consumer = queue.subscribe(manual_ack: true) do |delivery_info, properties, payload|
    mutex.synchronize do
      unacked_count += 1
      max_unacked = [max_unacked, unacked_count].max
      total_received += 1
      received_timestamps << {tag: delivery_info.delivery_tag, time: Time.now}

      puts "Received: #{payload} (#{unacked_count} unacked, #{total_received}/10 total)"
    end

    # Not acknowledging here, but you can experiment and do
  end

  # Publish messages
  puts "\nPublishing 10 messages..."
  10.times do |i|
    channel.default_exchange.publish("Message #{i}", routing_key: queue.name)
  end
  puts "All messages published to queue: #{queue_name}"

  # Wait for all messages to be received
  start_time = Time.now
  max_wait = 30

  while total_received < 10 && (Time.now - start_time) < max_wait
    sleep 0.5
    puts "Status: #{total_received}/10 received, #{unacked_count} unacknowledged"
  end

  # Clean up, maybe experiment here to see what happens
  ack_thread.join(1) # Give ack thread a chance to finish
  ack_thread.kill

  # Print summary
  puts "\nTEST SUMMARY: #{test_name}"
  puts "Total messages received: #{total_received}"
  puts "Maximum unacknowledged messages at once: #{max_unacked}"
  puts "Time elapsed: #{(Time.now - start_time).round(2)} seconds"

  consumer.cancel
  channel.queue_delete(queue_name)
  connection.close

  puts "\nTest completed: #{test_name}"
  sleep 2
end

# Run all three test scenarios
run_test("Default - No Prefetch Limit")
puts("With no prefetch limit, RabbitMQ delivers all messages immediately")
run_test("Channel Prefetch Count = 3", 3, true)
puts("With a prefetch limit of 3, RabbitMQ delivers exactly 3 messages, then waits for acknowledgments")
run_test("Consumer Prefetch Count = 2", 2, false)
puts("With a prefetch limit of 2, RabbitMQ delivers exactly 2 messages, then waits for acknowledgments")

puts "\nAll tests completed!"


