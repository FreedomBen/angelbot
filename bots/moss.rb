require 'slackbot_frd'

class Moss < SlackbotFrd::Bot
  EMERGENCY_TRIGGER_WORDS = %w(
    emergency
    urgent
  ).freeze

  CHANNEL_TRIGGER_WORDS = %w(
    <!channel
    <!group
    <!here
  ).freeze

  NORMAL_TRIGGER_WORDS = %w(
    moss
  ).freeze

  EMERGENCY_MESSAGES = [
    '"Dir sir/madam, FIRE!"',
    '"Is this the emergency services? Then which country am I speaking to?"',
    "> \"Subject: Fire. Dear Sir/Madam, I am writing to inform you of a fire that has broken out on the premises of 6330 S 3000 E... no, that's too formal.\"\n[deletes text, starts again]\n\> \"Fire - exclamation mark - fire - exclamation mark - help me - exclamation mark. 6330 S 3000 E. Looking forward to hearing from you. Yours truly, Maurice Moss.\""
  ].map! { |input| "#{input}\n\nIt's fine. I've sent an email." }.freeze

  NORMAL_MESSAGES = [
    "I'll just put this over here with the rest of the fire...",
    'I came here to drink milk, and kick _butt_ and I just finished my milk.',
    'Message for me!',
    'Friend Face',
    'An unopen door. Is a happy door. So we never answer ours when someone knocks',
    'This Jen, is the Internet',
    "Hello, IT? Yah-hah? Have you tried forcing an expected reboot? You see the driver hooks the function by patching the system call table, so it's not safe to unload it unless another thread's about to jump in there and do its stuff, and you don't want to end up in the middle of invalid memory."
  ].freeze

  ALL_TRIGGER_WORDS = EMERGENCY_TRIGGER_WORDS + CHANNEL_TRIGGER_WORDS + NORMAL_TRIGGER_WORDS

  def desired_channel?(channel)
    %w(it bps_test_graveyard).include?(channel)
  end

  def contains_any_trigger(_message)
    # ALL_TRIGGER_WORDS.any? { |word| message.downcase.include?(word) }
    # turn off for now
    false
  end

  def contains_trigger(words, message)
    words.any? { |word| message.downcase.include?(word) }
  end

  def response(message)
    if contains_trigger(EMERGENCY_TRIGGER_WORDS + CHANNEL_TRIGGER_WORDS, message)
      EMERGENCY_MESSAGES.sample
    else
      NORMAL_MESSAGES.sample
    end
  end

  def interested?(user, channel, message)
    message && desired_channel?(channel) && user != :bot
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if interested?(user, channel, message)
        if contains_any_trigger(message)
          slack_connection.send_message(
            channel: channel,
            message: response(message),
            username: 'Moss',
            avatar_emoji: ':moss:',
            thread_ts: thread_ts
          )
          slack_connection.post_reaction(name: 'moss', channel: channel, timestamp: timestamp)
          if contains_trigger(EMERGENCY_TRIGGER_WORDS, message)
            slack_connection.post_reaction(name: 'alert', channel: channel, timestamp: timestamp)
          end
        end
      end
    end
  end
end
