# frozen_string_literal: true

require 'amqp-client'
require 'dotenv/load'

# Opens and establishes a connection, channel is created automatically
client = AMQP::Client.new(ENV['CLOUDAMQP_URL']).start
# client = AMQP::Client.new("amqp://guest:guest@localhost").start

# Declare two queues, note that creating the queue happened in publisher, through a method called queue_declare. Naming might be a bit misleading
queue_email_meessages = client.queue 'email.notifications'
queue_password_messages = client.queue 'password.notifications'

counter = 0
# Subscribe to the queue
[queue_email_meessages, queue_password_messages].each do |queue|
  queue.subscribe do |msg|
    counter += 1
    # Add logic to handle the message here...
    puts "[📤] Message received [#{counter}]: #{msg.body}"
    # Acknowledge the message
    msg.ack
  rescue StandardError => e
    puts e.full_message
    msg.reject(requeue: false)
  end
end

# Close the connection when the script exits
at_exit do
  client.stop
  puts '[❎] Connection closed'
end

# Keep the consumer running
sleep
