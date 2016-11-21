require 'slackbot_frd'

class AndyBot < SlackbotFrd::Bot
  TRIGGER_WORDS = [
    'avanwagoner',
    'andy :van: :wagon: er',
    ':van: :wagon:',
    ':van::wagon:',
    ':van:  :wagon:',
  ].freeze

  def desired_channel?(channel)
    %w[the-real-commons unicycle bps_test_graveyard].include?(channel)
  end

  def contains_trigger(message)
    false
    # TRIGGER_WORDS.any? { |word| message.downcase.include?(word) }
  end

  def response
    '<@U02UQ709S|andy> ^^'
  end

  def interested?(user, channel, message)
    message && desired_channel?(channel) && user != :bot
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:|
      if interested?(user, channel, message)
        if contains_trigger(message)
          slack_connection.send_message(
            channel: channel,
            message: response
          )
        end
      end
    end
  end
end
