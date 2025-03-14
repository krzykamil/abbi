## Basics 01

First lesson/example set tries to show all the base parts that you can find the definitions on in GLOSSARY.md.

Both Elixir and Ruby code creates queues, exchanges, and binds them together. It does so from code level using language specific libraries (drops, gems).

This sort of thing is rarely done in code when using RabbitMQ, but it is a good way to get an overview of the main concepts, and how they can be reflected in code.

Using those libraries, you can use AMQP protocol without RabbitMQ abd instead some else AMQP message broker, but you will have some pain around that.

Connectivity and hosting the AMQP client is one thing. The examples use a RabbitMQ instance running in CloudAMQP. You can also host it locally, but writing instructions for Mac (🤢), Windows (🤮) and 1000s of Linux distros (🤓) would be a lot of work.

A free RabbitMQ instance can be set up for testing over at CloudAMQP. Refer to [this link](https://www.cloudamqp.com/blog/part1-rabbitmq-for-beginners-what-is-rabbitmq.html#set_up_instance)

Once you have an instance get an env variable CLOUDAMQP_URL and run the scripts with it loaded. You can find your CloudAMQP URL under Details in the CloudAMQP Console.

### The idea

...is to show but also encourage to experiment. Try to break the code. Add more to it. Add more logs. Add your own comments.
This example especially is very simple, but if you are new to amqp, it introduces and uses the most basic and important concepts. Try it.
