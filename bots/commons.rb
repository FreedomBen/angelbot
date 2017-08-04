require 'slackbot_frd'

class CommonsBot < SlackbotFrd::Bot
  def redirected_to(channel)
    return '#unicycle' if channel == 'canvadocs'
    '#content-commons-users or #unicycle'
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      channels = %w[commons canvadocs]
      ignored_users = %w[bp angel caleb kate andy jgorr zach aaronshaf dnehring]
      if message && user != :bot && channels.include?(channel) && !ignored_users.include?(user) && timestamp != thread_ts
        SlackbotFrd::Log.info("Auto-responding to user '#{user}' in channel '#{channel}'")
        slack_connection.send_message(
          channel: channel,
          message: ":wave: #{user}!  This channel isn't really used anymore.  You would probably have better luck asking in #{redirected_to(channel)}\n\n_NOTE: this is an automated reply_",
          thread_ts: thread_ts
        )
      end
    end
  end
end
