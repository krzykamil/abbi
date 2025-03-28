# frozen_string_literal: true

require 'bunny'
require 'uri'


channel.basic_publish('Kocham Cię', '', 'love_letters')
channel.basic_publish('I love you', '', 'love_letters')
channel.basic_publish('Jeg elsker deg', '', 'love_letters')
channel.basic_publish('я тебя люблю', '', 'love_letters')
channel.basic_publish('Ich liebe dich', '', 'love_letters')

