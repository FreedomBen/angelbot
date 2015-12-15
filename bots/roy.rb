require 'slackbot_frd'

class Roy < SlackbotFrd::Bot
  TIME_FILE = "/tmp/it-roybot-time-file.txt"

  def desired_channel?(channel)
    %w[it bps_test_graveyard].include?(channel)
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:|
      if message && desired_channel?(channel) && user != :bot
        resp = response(message)
        if resp
          slack_connection.send_message(
            channel: channel,
            message: resp,
            username: "Roy",
            avatar_emoji: ":roy:"
          )
        end
      end
    end
  end

  def response(message)
    return nil unless message
    m = message.downcase
    if m.include?('roy') || m.include?("<!channel") || m.include?("<!group") || m.include?("<!here")
      return "Hello, IT, have you tried turning it off and on again?"
    elsif m =~ /ticket/ && ((m =~ /file/) || (m =~ /is/ && m =~ /there/) || (m =~ /submit/) || (m =~ /open/)) && time_expired?
      capture_time
      # submit ticket
      # open ticket
      # file ticket
      # is there ticket
      return "No ticket?\n\nhttp://i.imgur.com/avwx7Zj.gif\nhttp://media.giphy.com/media/CHROEms0iVuda/giphy.gif"
    end
    nil
  end

  def time_expired?
    return true unless File.exist?(TIME_FILE)
    (JSON.parse(File.read(TIME_FILE))["time"] + 60) <= Time.now.to_i
  end

  def capture_time
    File.write(TIME_FILE, { time: Time.now.to_i }.to_json)
  end
end
