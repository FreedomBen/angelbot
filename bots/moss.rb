require 'slackbot_frd'

class Moss < SlackbotFrd::Bot
  TRIGGER_WORDS = %w[
    moss
    emergency
    urgent
    <!channel
    <!group
    <!here
  ].freeze

  MESSAGES = [
    "I came here to drink milk, and kick _butt_ and I just finished my milk.",
    "Message for me!",
    "Friend Face",
    "I'll just put this over here with the rest of the fire...",
    "An unopen door. Is a happy door. So we never answer ours when someone knocks",
    "This Jen, is the Internet",
    "Dir sir/madam, FIRE!",
    "Is this the emergency services? Then which country am I speaking to?",
    "It's fine. I've sent an email.",
    "Subject: Fire. Dear Sir/Madam, I am writing to inform you of a fire that has broken out on the premises of 123 Cavendon Road... no, that's too formal.\n[deletes text, starts again]\nFire - exclamation mark - fire - exclamation mark - help me - exclamation mark. 123 Cavendon Road. Looking forward to hearing from you. Yours truly, Maurice Moss.",
    "Hello, IT? Yah-hah? Have you tried forcing an expected reboot? You see the driver hooks the function by patching the system call table, so it's not safe to unload it unless another thread's about to jump in there and do its stuff, and you don't want to end up in the middle of invalid memory."
  ].freeze

  def desired_channel?(channel)
    %w[it bps_test_graveyard].include?(channel)
  end

  def contains_trigger(message)
    TRIGGER_WORDS.any?{ |word| message.include?(word) }
  end

  def response
    MESSAGES.shuffle.first
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:|
      if message && desired_channel?(channel) && user != :bot && contains_trigger(message)
        slack_connection.send_message(
          channel: channel,
          message: response,
          username: "Moss",
          avatar_emoji: ":moss:"
        )
      end
    end
  end
end
