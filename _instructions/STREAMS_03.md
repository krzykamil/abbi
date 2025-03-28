## Stream 03

Client applications could talk to a Stream via an AMQP client library, in both ruby and elixir, just as they do with queues. 

However, it is recommended to use the dedicated Streams protocol plugin and its associate client libraries.

RabbitMQ client libraries abstract the low-level details of connecting to a queue or stream in RabbitMQ. Think of them as the packages that simplify image processing, or making http requests in your favorite programming languages.

Since streams are a bit "more", a slightly more advanced concept than what was shown in the basics, a slightly more advanced tools are recommended.

A non drop/gem/library approach is also possible, but outside of scope for this.

### The idea
Is to show the difference between regular queue (shown in the first example) and streams.
