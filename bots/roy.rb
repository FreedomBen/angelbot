require 'slackbot_frd'
require 'tzinfo'
require 'tzinfo/data'

class Roy < SlackbotFrd::Bot
  TICKET_REGEX = /^roy:?\s+(?:open)?\s*ticket\s+(?:to|for)\s+(.*)/i
  TIMEZONE = "US/Mountain"
  BUSINESS_HOURS = (8...17)
  OFFLINE_MESSAGE = %(I'm sorry; you've reached us after-hours. If this is an emergency, use "/itpd your issue" or call +1-833-255-9717 or +1-801-508-6911 to contact our on-call technician. Otherwise, create a ticket via our portal: https://instructure.atlassian.net/servicedesk/customer/portal/1)
  DEPRECATED_MESSAGE = %(Sorry! I can't do this anymore. Please create a ticket here: https://instructure.atlassian.net/servicedesk/customer/portal/1)
  SUGGESTION_MESSAGE = %(If you are looking to create ticket, do so via our portal: https://instructure.atlassian.net/servicedesk/customer/portal/1)

  def desired_channel?(channel)
    %w[it angels_sandbox].include?(channel)
  end

  def contains_jiras(str)
    str.downcase =~ /(^|\s)\(?ITSD-\d{1,9}\)?[.!?,;)]*($|\s)/i
  end

  def during_business_hours?
    current_time = TZInfo::Timezone.get(TIMEZONE).now
    !(current_time.saturday? || current_time.sunday?) && (BUSINESS_HOURS.cover?(current_time.hour))
  end

  def contains_ticket?(message)
    message =~ TICKET_REGEX
  end

  def might_need_suggestion?(m)
    ((m.include?('roy') || m.include?('<!channel') || m.include?('<!group') || m.include?('<!here')) && !contains_jiras(message)) ||
    (m =~ /ticket/ && ((m =~ /file/) || (m =~ /is/ && m =~ /there/) || (m =~ /submit/) || (m =~ /open/) || (m =~ /send/)))
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if (message && desired_channel?(channel) && user != :bot && timestamp != thread_ts) &&
         (resp = response(sc: slack_connection, user: user, message: message))
        slack_connection.send_message(
          channel: channel,
          message: resp,
          username: 'Roy',
          avatar_emoji: ':roy:',
          parse: contains_ticket?(message) ? 'none' : 'full',
          thread_ts: thread_ts
        )
      end
    end
  end

  def response(sc:, user:, message:)
    return nil unless message
    m = message.downcase
    return OFFLINE_MESSAGE if (contains_ticket?(m) || might_need_suggestion?(m)) && !during_business_hours?
    if contains_ticket?(m)
      SlackbotFrd::Log.info("User '#{user}' is attempting to open an IT ticket through Roy. message: '#{message}'")
      return DEPRECATED_MESSAGE
    elsif might_need_suggestion?(m)
      return SUGGESTION_MESSAGE
    end
    nil
  end
end
