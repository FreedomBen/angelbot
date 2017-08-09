require 'slackbot_frd'

class GreetingBot < SlackbotFrd::Bot
  def add_callbacks(slack_connection)
    slack_connection.on_channel_joined(user: :any, channel: 'angelbot') do |user:, channel:|
      slack_connection.send_message(
        channel: channel,
        message: ":wave: ohai #{user}, welcome to the ##{channel} 24/7 party! :party-dawg:"
      )
    end
  end
end
