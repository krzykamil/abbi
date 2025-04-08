# frozen_string_literal: true

# dead_letter_demo.rb
require 'bunny'
require 'securerandom'

# What we have here:
# Setting up a dead letter exchange
# Configuring a queue to use a dead letter exchange
# Messages being rejected and sent to the dead letter queue
# Examining dead letter metadata
# Retrying messages from the dead letter queue

class DeadLetterDemo
  def initialize
    # Generate unique names for this run
    @id = SecureRandom.hex(3)
    @main_queue = "main_queue_#{@id}"
    @dlx_name = "dlx_#{@id}"
    @dl_queue = "dead_letter_queue_#{@id}"
    @main_exchange = "main_exchange_#{@id}"
    @retry_exchange = "retry_exchange_#{@id}"

    puts "\n🔌 Connecting to RabbitMQ..."
    rabbitmq_url = ENV['CLOUDAMQP_URL'] || 'amqp://guest:guest@localhost:5672/%2f'
    @connection = Bunny.new(rabbitmq_url)
    @connection.start
    @channel = @connection.create_channel

    setup_dead_letter_infrastructure
  end

  def setup_dead_letter_infrastructure
    puts "\n🏗️ Setting up dead letter infrastructure..."

    # 1. Create the Dead Letter Exchange
    puts "  ↪ Creating Dead Letter Exchange: #{@dlx_name}"
    @dlx = @channel.direct(@dlx_name)

    # 2. Create the Dead Letter Queue
    puts "  ↪ Creating Dead Letter Queue: #{@dl_queue}"
    @dl_queue_obj = @channel.queue(@dl_queue, durable: true)
    @dl_queue_obj.bind(@dlx, routing_key: @main_queue)

    # 3. Create a Main Exchange (for publishing)
    puts "  ↪ Creating Main Exchange: #{@main_exchange}"
    @main_exchange_obj = @channel.direct(@main_exchange)

    # 4. Create a Retry Exchange (for later requeuing)
    puts "  ↪ Creating Retry Exchange: #{@retry_exchange}"
    @retry_exchange_obj = @channel.direct(@retry_exchange)

    # 5. Create the Main Queue with dead letter configuration
    puts "  ↪ Creating Main Queue with DLX: #{@main_queue}"
    @main_queue_obj = @channel.queue(
      @main_queue,
      durable: true,
      arguments: {
        'x-dead-letter-exchange' => @dlx_name,
        'x-dead-letter-routing-key' => @main_queue
      }
    )

    # Bind the main queue to the main exchange
    @main_queue_obj.bind(@main_exchange_obj, routing_key: @main_queue)

    # Bind the main queue to the retry exchange (for retrying)
    @main_queue_obj.bind(@retry_exchange_obj, routing_key: @main_queue)

    puts "✅ Dead letter infrastructure setup complete!"
  end

  def run_demo
    setup_main_consumer
    setup_dl_consumer
    publish_test_messages

    puts "\n⏳ Waiting for all operations to complete... (just pretending it takes longer than it does for better demonstration)"
    sleep 10

    retry_dead_letters
    puts "\n⏳ Waiting for retried messages to be processed... simulating that it happens later with sleep"
    sleep 5
    cleanup
  end

  def setup_main_consumer
    puts "\n👂 Setting up consumer for main queue..."

    @main_consumer = @main_queue_obj.subscribe(manual_ack: true) do |delivery_info, _properties, payload|
      puts "\n📨 [MAIN QUEUE] Received message: #{payload}"

      # We just simulate that for some reason processing the message fails. In regular app, something could be wrong with payload or whatever
      if payload.include?("fail")
        puts "❌ [MAIN QUEUE] Message processing failed! Rejecting message."
        @channel.reject(delivery_info.delivery_tag, false) # reject without requeue
      else
        # Simulate processing time
        puts "⏱️ [MAIN QUEUE] Processing message..."
        sleep 1
        puts "✅ [MAIN QUEUE] Message processed successfully! Acknowledging."
        @channel.ack(delivery_info.delivery_tag)
      end
    end
  end

  def setup_dl_consumer
    puts "\n👂 Setting up consumer for dead letter queue..."

    @dl_consumer = @dl_queue_obj.subscribe(manual_ack: true) do |delivery_info, properties, payload|
      puts "\n💀 [DEAD LETTER QUEUE] Received dead letter: #{payload}"

      # Extract original headers (if any). In this demo we just care about this one, but in real application we might care about other headers
      headers = properties.headers || {}
      death_info = headers["x-death"]

      if death_info
        count = death_info.first["count"]
        queue = death_info.first["queue"]
        reason = death_info.first["reason"]
        puts "ℹ️ [DEAD LETTER QUEUE] Death reason: #{reason}, original queue: #{queue}, count: #{count}"
      end

      # Just log the message, don't acknowledge yet (we'll retry later)
      puts "📝 [DEAD LETTER QUEUE] Message stored for later retry."

      # Store the delivery tag for later acknowledgment
      @dl_delivery_tags ||= []
      @dl_delivery_tags << delivery_info.delivery_tag
    end
  end

  def publish_test_messages
    puts "\n📤 Publishing test messages to main queue..."

    # Publish a successful message
    @main_exchange_obj.publish(
      "This message will succeed",
      routing_key: @main_queue,
      persistent: true
    )
    puts "  ↪ Published message: 'This message will succeed'"

    # Publish a message that will fail and be dead-lettered
    @main_exchange_obj.publish(
      "This message will fail",
      routing_key: @main_queue,
      persistent: true
    )
    puts "  ↪ Published message: 'This message will fail'"

    # Publish another successful message
    @main_exchange_obj.publish(
      "This is another successful message",
      routing_key: @main_queue,
      persistent: true
    )
    puts "  ↪ Published message: 'This is another successful message'"

    # Publish another failing message
    @main_exchange_obj.publish(
      "This will also fail",
      routing_key: @main_queue,
      persistent: true
    )
    puts "  ↪ Published message: 'This will also fail'"
  end

  def retry_dead_letters
    return unless @dl_delivery_tags && !@dl_delivery_tags.empty?

    puts "\n🔄 Retrying messages from dead letter queue..."

    count = @dl_delivery_tags.length
    puts "  ↪ Found #{count} messages to retry"

    # Process each delivery tag (message) from the dead letter queue
    @dl_delivery_tags.each_with_index do |tag, i|
      puts "🔄 Retrying dead letter ##{i+1}..."

      # Acknowledge the message in the dead letter queue
      @channel.ack(tag)
      puts "  ↪ Acknowledged message in dead letter queue"

      @retry_exchange_obj.publish(
        "Retried message ##{i+1} (was dead-lettered)",
        routing_key: @main_queue,
        persistent: true
      )
      puts "  ↪ Republished message to retry exchange"
    end

    @dl_delivery_tags = []
  end

  def cleanup
    puts "\n🧹 Cleaning up resources..."

    @main_consumer.cancel if @main_consumer
    @dl_consumer.cancel if @dl_consumer
    @main_queue_obj.delete if @main_queue_obj
    @dl_queue_obj.delete if @dl_queue_obj
    @channel.exchange_delete(@dlx_name) if @dlx
    @channel.exchange_delete(@main_exchange) if @main_exchange_obj
    @channel.exchange_delete(@retry_exchange) if @retry_exchange_obj
    @connection.close if @connection

    puts "✅ Cleanup complete!"
  end
end

# Run the demo
puts "🐰 RabbitMQ Dead Letter Exchange Demo"
puts "======================================"
demo = DeadLetterDemo.new
demo.run_demo
puts "======================================"
puts "🎉"

# To further improve the system, include an incremented property in the message body indicating the number of times the message was received. This requires handling dead letters in a separate consumer but allows you to eventually drop messages or push them to storage based on this number. If a message has been retried 10 times, it probably doesn't need to be retried again.
