# frozen_string_literal: true

require 'amqp-client'
require 'dotenv/load'
require 'json'

# Opens and establishes a connection
# connection = AMQP::Client.new(ENV['CLOUDAMQP_URL']).connect
connection = AMQP::Client.new("amqp://guest:guest@localhost").connect

# Open a channel
channel = connection.channel
puts '[✅] Connection over channel established'

# Create an exchange called "emails"
channel.exchange_declare('emails', 'direct')

# Create a queue
channel.queue_declare('email.notifications')
channel.queue_declare('password.notifications')

# Bind the queue to the exchange: queue_bind(name, exchange, binding_key)
channel.queue_bind('email.notifications', 'emails', 'notification')
channel.queue_bind('password.notifications', 'emails', 'resetpassword')

# Define a method for publishing messages to the queue
def send_to_queue(channel, routing_key, email, name, body)
  msg = "{#{email}, #{name}, #{body}}".to_json
  # Publish function expects: publish(body, exchange, routing_key)
  channel.basic_publish(msg, 'emails', routing_key)
  puts "[📥] Message sent to queue #{msg}"
end

# Now let's send some messages to the queue over our channel
send_to_queue channel, 'notification', 'example@example.com', 'John Doe', 'Your order has been received'
send_to_queue channel, 'notification', 'example@example.com', 'Jane Doe', 'The product is back in stock'
send_to_queue channel, 'resetpassword', 'example@example.com', 'Willem Dafoe', 'Here is your new password'

begin
  connection.close
  puts '[❎] Connection closed'
rescue StandardError => e
  puts "Error: #{e}"
end
