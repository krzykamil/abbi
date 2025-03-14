# BasicsElixir01

```
mix deps.get
mix deps.compile

CLOUDAMQP_URL="your_key"  mix run -e "Consumer.consume"

CLOUDAMQP_URL="your_key"  mix run -e "Publisher.publish"
(or export CLOUDAMQP_URL="your_key")
```

