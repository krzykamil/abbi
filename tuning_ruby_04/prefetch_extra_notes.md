### NOTE ON SCRIPT:
1. Channel vs Consumer Prefetch: Both channel-level (global=true) and consumer-level (global=false) prefetch settings worked the same way in this single-consumer scenario.
2. You can try working on having more than one consumer to see a difference in behaviour

### WHEN TO USE:
1. With only one consumer, the difference between channel prefetch and consumer prefetch isn't really observable.
2. In a real-world scenario, prefetch limits become more important when:
3. Processing messages takes variable time (some messages take more to process for the consumer than others)
4. Multiple consumers are competing for messages
5. System resources are limited
6. Message order processing matters

## Summary of the script results:

```
Default - No Prefetch Limit
All 10 messages were received immediately
Maximum unacknowledged messages: 10
Time elapsed: 1.5 seconds
RabbitMQ delivered all messages at once without waiting for acknowledgments
```

```
Channel Prefetch Count = 3
Initially only 3 messages were received
Maximum unacknowledged messages: 3
Time elapsed: 6.5 seconds
New messages were only delivered after previous ones were acknowledged
The "3 unacked" limit was strictly maintained
```

```
Consumer Prefetch Count = 2
Initially only 2 messages were received
Maximum unacknowledged messages: 2
Time elapsed: 7.0 seconds
New messages were only delivered after previous ones were acknowledged
The "2 unacked" limit was strictly maintained
```

### Main takeaways when it comes to performance:
1. Resource Management: Prefetch prevents consumers from being overwhelmed with too many messages at once.
2. Fair Distribution: In multi-consumer scenarios, prefetch ensures that busy consumers don't hoard messages they can't process quickly.
3. Memory Control: Prefetch limits the amount of memory needed on the client side for storing unprocessed messages.
4. Throughput vs. Latency Balance: A higher prefetch allows higher throughput but might increase latency for individual messages; a lower prefetch reduces throughput but ensures more consistent processing times.

### The size matters:
**A larger prefetch count generally improves the rate of message delivery**. The broker does not need to wait for acknowledgments as often and the communication between the broker and consumers decreases. Still, smaller prefetch values can be ideal for distributing messages across larger systems. Smaller values maintain an even rate of message consumption. A value of one helps ensure equal message distribution.

**A prefetch count that is set too small may hurt performance** since RabbitMQ might end up in a state where the broker is waiting to get permission to send more messages. The image below illustrates a long idling time. In the figure, we have a QoS prefetch setting of one (1). This means that RabbitMQ won't send out the next message until after the round trip completes (deliver, process, acknowledge). Round-trip time in this figure is in total 125ms with a processing time of only 5ms.

**A large prefetch count, on the other hand, could take lots of messages off the queue and deliver all of them to one single consumer, keeping the other consumers in an idling state, as illustrated in the figure below:

#### What size is right for me?

The one that satisfies your needs of course!

If you have one single or only a few consumers processing messages quickly, better to prefetch many messages at once to keep your client as busy as possible. If you have about the same processing time all the time and network behavior remains the same, simply take the total round trip time and divide by the processing time on the client for each message to get an estimated prefetch value.

Many consumers and short processing time? Try a lower prefetch value. A value that is too low will keep the consumers idling a lot since they need to wait for messages to arrive. A value that is too high may keep one consumer busy while other consumers are being kept in an idling state.

And if you have many consumers and/or long processing time, set the prefetch count to one so that messages are evenly distributed among all your consumers.

# **Please note that if your client auto-acks messages, the prefetch value will have no effect.**

# Avoid the usual mistake of having an unlimited prefetch, where one client receives all messages and runs out of memory and crashes, causing all the messages to be re-delivered.
