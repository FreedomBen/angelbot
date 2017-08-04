require 'slackbot_frd'

class EchoChamberBot < SlackbotFrd::Bot
  TRIGGER_WORDS = %w[
    linux
    mac
    android
    ios
    iphone
    windows
  ].freeze

  GENERIC_STATEMENT_BASE = 'GENERIC_STATEMENT_BASE'.freeze
  SUBJECT_STATEMENT_BASE = 'SUBJECT_STATEMENT_BASE'.freeze

  def generic_statement(user)
    [
      "I hear you #{user}.",
      "I couldn't agree more #{user}.",
      "That is so true #{user}.",
      "I'm glad you're here #{user}.",
      "I feel the same way #{user}.",
      "That's such a great point of view #{user}.",
      "#{user} we are vibing here."
    ].sample
  end

  def subject_statement(subject)
    [
      "oh yeah, #{SUBJECT_STATEMENT_BASE} is the greatest. :heart:",
      "More people need #{SUBJECT_STATEMENT_BASE} in their lives.",
      "Someday #{SUBJECT_STATEMENT_BASE} will take over the world."
    ].sample.gsub(SUBJECT_STATEMENT_BASE, subject)
  end

  def desired_channel?(channel)
    %w[echo_chamber bps_test_graveyard2].include?(channel)
  end

  def response(user, message)
    tword = TRIGGER_WORDS.select { |word| message.downcase.include?(word) }
    if tword.count != 1
      generic_statement(user)
    else
      subject_statement(tword.first)
    end
  end

  def interested?(user, channel, message)
    message && desired_channel?(channel) && user != :bot && user != 'angel'
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if interested?(user, channel, message)
        slack_connection.send_message(
          channel: channel,
          message: response(user, message),
          thread_ts: thread_ts
        )
      end
    end
  end
end
