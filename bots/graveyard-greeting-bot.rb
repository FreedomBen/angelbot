require 'slackbot_frd'

class GraveyardGreetingBot < SlackbotFrd::Bot
  def add_callbacks(slack_connection)
    slack_connection.on_channel_joined(user: :any, channel: 'bps_test_graveyard') do |user:, channel:|
      slack_connection.send_message(
        channel: channel,
        message: ":skull: ohai #{user}, welcome to ##{channel}! :ghost:",
        username: 'Graveyard Greeting Bot',
        avatar_emoji: ':graveyard:'
      )
    end
  end
end
