## Basics 02

Refer to: https://www.rabbitmq.com/docs/download to install rabbitmq locally on your machine.


### The idea
...is to familiarize yourself with the RabbitMQ server and interface. If you are working in a project that uses RabbitMQ, it is possible than the interface has lots and lots of data,
and this is intimidating and hard to grasp, so it is better to start and the basics rather than do a deep dive.

### Changing from using the CLOUD to local

After installing local RabbitMQ and the plugin responsible for UI (rabbitmq_management) we can access the UI:
```
$ rabbitmq-server
```

_address_: http://127.0.0.1:15672/

And then change the code from the first example to use the local RabbitMQ instance.

publisher.rb
```ruby
# connection = AMQP::Client.new(ENV['CLOUDAMQP_URL']).connect
connection = AMQP::Client.new("amqp://guest:guest@localhost").connect

```
consumer.rb
```ruby
# client = AMQP::Client.new(ENV['CLOUDAMQP_URL']).start
client = AMQP::Client.new("amqp://guest:guest@localhost").start
```

This is just to show that you are not bound to using cloud solutions and don't have to rely on rabbitmq etc.

The code is still using the base AMQP library, not bunny, not hutch, but you can still do all the things AMQP allows to do without them, locally, or on self-managed machines.
