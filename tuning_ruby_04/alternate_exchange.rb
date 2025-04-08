# frozen_string_literal: true
# alternate_exchange_demo.rb
require 'bunny'
require 'securerandom'

# In here you can see
# Basic Setup: How to configure an alternate exchange for a main exchange
# Unroutable Messages: How messages with invalid routing keys get redirected to the alternate exchange
# Mandatory Flag Behavior: How the mandatory flag interacts with alternate exchanges
# Return Handler: How to set up a return handler for truly unroutable messages
# Message Tracking: How to preserve original routing information through headers

class AlternateExchangeDemo
  def initialize
    @id = SecureRandom.hex(3)
    @main_exchange = "main_exchange_#{@id}"
    @alt_exchange = "alt_exchange_#{@id}"
    @main_queue = "main_queue_#{@id}"
    @alt_queue = "alt_queue_#{@id}"

    puts "\n🔌 Connecting to RabbitMQ..."
    rabbitmq_url = ENV['CLOUDAMQP_URL'] || 'amqp://guest:guest@localhost:5672/%2f'
    @connection = Bunny.new(rabbitmq_url)
    @connection.start
    @channel = @connection.create_channel

    setup_alternate_exchange_infrastructure
  end

  def setup_alternate_exchange_infrastructure
    puts "\n🏗️ Setting up alternate exchange infrastructure..."

    # 1. Create the Alternate Exchange (must be created first)
    puts "  ↪ Creating Alternate Exchange: #{@alt_exchange}"
    @alt_exchange_obj = @channel.fanout(@alt_exchange)

    # 2. Create the Main Exchange with alternate exchange configuration
    puts "  ↪ Creating Main Exchange with AE: #{@main_exchange}"
    @main_exchange_obj = @channel.direct(
      @main_exchange,
      arguments: {
        'alternate-exchange' => @alt_exchange
      }
    )

    # 3. Create the Main Queue
    puts "  ↪ Creating Main Queue: #{@main_queue}"
    @main_queue_obj = @channel.queue(@main_queue, durable: true)
    @main_queue_obj.bind(@main_exchange_obj, routing_key: "valid_key")

    # 4. Create the Alternate Queue (for unroutable messages)
    puts "  ↪ Creating Alternate Queue: #{@alt_queue}"
    @alt_queue_obj = @channel.queue(@alt_queue, durable: true)
    @alt_queue_obj.bind(@alt_exchange_obj)

    puts "✅ Alternate exchange infrastructure setup complete!"
  end

  def run_demo
    setup_main_consumer
    setup_alt_consumer
    setup_return_handler
    publish_test_messages

    # Wait for all operations to complete
    puts "\n⏳ Waiting for all operations to complete..."
    sleep 10
    cleanup
  end

  def setup_main_consumer
    puts "\n👂 Setting up consumer for main queue..."

    @main_consumer = @main_queue_obj.subscribe do |delivery_info, properties, payload|
      puts "\n📨 [MAIN QUEUE] Received message: #{payload}"
      puts "  ↪ Routing key: #{delivery_info.routing_key}"
    end
  end

  def setup_alt_consumer
    puts "\n👂 Setting up consumer for alternate queue..."

    @alt_consumer = @alt_queue_obj.subscribe do |_delivery_info, properties, payload|
      puts "\n⚠️ [ALTERNATE QUEUE] Received unroutable message: #{payload}"

      # Extract original routing key from headers if available
      headers = properties.headers || {}
      if headers["x-original-routing-key"]
        puts "  ↪ Original routing key: #{headers["x-original-routing-key"]}"
      end
    end
  end

  def setup_return_handler
    puts "\n🔄 Setting up return handler for mandatory messages..."

    @channel.confirm_select

    # Then set up a return handler
    @channel.on_return do |return_info, properties, content|
      puts "\n🔙 [RETURNED] Message returned by RabbitMQ: #{content}"
      puts "  ↪ Reply code: #{return_info.reply_code}"
      puts "  ↪ Reply text: #{return_info.reply_text}"
      puts "  ↪ Exchange: #{return_info.exchange}"
      puts "  ↪ Routing key: #{return_info.routing_key}"
    end
  end

  def publish_test_messages
    puts "\n📤 Publishing test messages..."

    # Scenario 1: Message with valid routing key
    puts "\n🔹 Scenario 1: Message with valid routing key"
    @main_exchange_obj.publish(
      "This message has a valid routing key",
      routing_key: "valid_key",
      persistent: true,
      headers: { "x-original-routing-key" => "valid_key" }
    )
    puts "  ↪ Published message with routing key: 'valid_key'"

    # Scenario 2: Message with invalid routing key (will go to alternate exchange)
    puts "\n🔹 Scenario 2: Message with invalid routing key (will go to alternate exchange)"
    @main_exchange_obj.publish(
      "This message has an invalid routing key and will go to the alternate exchange",
      routing_key: "invalid_key",
      persistent: true,
      headers: { "x-original-routing-key" => "invalid_key" }
    )
    puts "  ↪ Published message with routing key: 'invalid_key'"

    # Scenario 3: Message with invalid routing key and mandatory flag
    puts "\n🔹 Scenario 3: Message with invalid routing key and mandatory flag"
    puts "  ↪ Note: Since we have an alternate exchange, this should still be delivered to the alternate exchange"
    @main_exchange_obj.publish(
      "This message has an invalid routing key but has mandatory flag set",
      routing_key: "another_invalid_key",
      mandatory: true,
      persistent: true,
      headers: { "x-original-routing-key" => "another_invalid_key" }
    )
    puts "  ↪ Published message with routing key: 'another_invalid_key' and mandatory flag"

    # Scenario 4: Message to non-existent exchange with mandatory flag
    puts "\n🔹 Scenario 4: Message to non-existent exchange with mandatory flag"
    begin
      non_existent_exchange = @channel.direct("non_existent_exchange_#{@id}", passive: true)
      non_existent_exchange.publish(
        "This message is sent to a non-existent exchange",
        routing_key: "any_key",
        mandatory: true,
        persistent: true
      )
    rescue Bunny::NotFound => e
      puts "  ↪ Error: #{e.message}"
      puts "  ↪ This is expected - the exchange doesn't exist"

      # Create a temporary exchange to demonstrate return handler
      puts "  ↪ Creating a temporary exchange to demonstrate return handler"
      temp_exchange = @channel.direct("temp_exchange_#{@id}")
      temp_exchange.publish(
        "This message will be returned because there's no binding",
        routing_key: "unbound_key",
        mandatory: true,
        persistent: true
      )
      puts "  ↪ Published message with routing key: 'unbound_key' and mandatory flag"
    end
  end

  def cleanup
    puts "\n🧹 Cleaning up resources..."
    @main_consumer.cancel if @main_consumer
    @alt_consumer.cancel if @alt_consumer
    @main_queue_obj.delete if @main_queue_obj
    @alt_queue_obj.delete if @alt_queue_obj
    @channel.exchange_delete(@main_exchange) if @main_exchange_obj
    @channel.exchange_delete(@alt_exchange) if @alt_exchange_obj
    @channel.exchange_delete("temp_exchange_#{@id}") rescue nil  # Delete the temporary exchange if it exists
    @connection.close if @connection
    puts "✅ Cleanup complete!"
  end
end

# Run the demo
puts "🐰 RabbitMQ Alternate Exchange Demo"
puts "==================================="
demo = AlternateExchangeDemo.new
demo.run_demo
puts "\n✨"

