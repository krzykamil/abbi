defmodule Publisher do
  require Logger
  alias AMQP.Connection
  alias AMQP.Channel
  alias AMQP.Basic
  alias AMQP.Exchange
  alias AMQP.Queue

  def publish do
    amqp_url = System.get_env("CLOUDAMQP_URL")
    unless amqp_url, do: raise "Environment variable CLOUDAMQP_URL is not set"

    # Open a connection and channel
    {:ok, connection} = Connection.open(amqp_url, ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)
    Logger.info("[✅] Connection over channel established")

    # Create an exchange called "emails" - handle if it already exists
    try do
      # First try to check if it exists (passive mode)
      :ok = Exchange.declare(channel, "emails", :direct, passive: true)
      Logger.info("Exchange 'emails' already exists, continuing...")
    rescue
      _ ->
        # If it doesn't exist, create it
        :ok = Exchange.declare(channel, "emails", :direct)
        Logger.info("Exchange 'emails' created")
    end

    # Create queues
    {:ok, _} = Queue.declare(channel, "email.notifications", durable: true)
    {:ok, _} = Queue.declare(channel, "password.notifications", durable: true)

    # Bind the queues to the exchange
    :ok = Queue.bind(channel, "email.notifications", "emails", routing_key: "notification")
    :ok = Queue.bind(channel, "password.notifications", "emails", routing_key: "resetpassword")

    # Publish messages
    send_to_queue(channel, "notification", "example@example.com", "John Doe", "Your order has been received")
    send_to_queue(channel, "notification", "example@example.com", "Jane Doe", "The product is back in stock")
    send_to_queue(channel, "resetpassword", "example@example.com", "Willem Dafoe", "Here is your new password")

    # Close the connection
    Connection.close(connection)
    Logger.info("[❎] Connection closed")
  end

  # Helper function to publish messages
  defp send_to_queue(channel, routing_key, email, name, body) do
    # Format the message as a string for now
    msg = "{\"email\": \"#{email}\", \"name\": \"#{name}\", \"body\": \"#{body}\"}"

    # Publish the message
    Basic.publish(channel, "emails", routing_key, msg)
    Logger.info("[📥] Message sent to queue: #{msg}")
  end
end
