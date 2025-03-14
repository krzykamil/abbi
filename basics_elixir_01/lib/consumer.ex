# lib/consumer.ex
defmodule Consumer do
  require Logger
  alias AMQP.Connection
  alias AMQP.Channel
  alias AMQP.Basic
  alias AMQP.Queue

  def consume do
    amqp_url = System.get_env("CLOUDAMQP_URL")
    unless amqp_url, do: raise "Environment variable CLOUDAMQP_URL is not set"

    # Open a connection and channel
    {:ok, connection} = Connection.open(amqp_url, ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)

    # Set up queues
    queue_email = "email.notifications"
    queue_password = "password.notifications"

    # Ensure queues exist
    {:ok, _} = Queue.declare(channel, queue_email, durable: true)
    {:ok, _} = Queue.declare(channel, queue_password, durable: true)

    # Consume messages from both queues
    {:ok, _consumer_tag1} = Basic.consume(channel, queue_email, nil)
    {:ok, _consumer_tag2} = Basic.consume(channel, queue_password, nil)

    Logger.info("Waiting for messages. To exit press CTRL+C, CTRL+C")

    # Start the consumer process
    wait_for_messages(channel)
  end

  # Process to wait for and handle messages
  defp wait_for_messages(channel) do
    receive do
      {:basic_deliver, payload, meta} ->
        # Process the message
        handle_message(payload, meta, channel)
        # Continue waiting for more messages
        wait_for_messages(channel)
    end
  end

  # Handle received message
  defp handle_message(payload, meta, channel) do
    # Just log the raw payload for now
    Logger.info("[📤] Message received: #{inspect(payload)}")
    # Acknowledge the message
    Basic.ack(channel, meta.delivery_tag)
  rescue
    e ->
      Logger.error("Error processing message: #{inspect(e)}")
      Basic.reject(channel, meta.delivery_tag, requeue: false)
  end
end
