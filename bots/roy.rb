require 'slackbot_frd'

class Roy < SlackbotFrd::Bot
  TIME_FILE = '/tmp/it-roybot-time-file.txt'
  OPEN_EXAMPLE = 'roy: please open a service request for something that is wrong'
  TICKET_REGEX = /roy:?\s+.*(request|ticket)\s+for\s+(.*)/i

  def desired_channel?(channel)
    %w[it bps_test_graveyard].include?(channel)
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:|
      if message && desired_channel?(channel) && user != :bot
        resp = response(user: user, message: message)
        if resp
          slack_connection.send_message(
            channel: channel,
            message: resp,
            username: 'Roy',
            avatar_emoji: ':roy:',
            parse: contains_ticket?(message) ? 'none' : 'full'
          )
          slack_connection.post_reaction(
            name: 'roy',
            channel: channel,
            timestamp: timestamp
          )
        end
      end
    end
  end

  def contains_ticket?(message)
    message =~ TICKET_REGEX
  end

  def ticket_summary(message)
    message.match(TICKET_REGEX).captures[1]
  end

  def response(user:, message:)
    return nil unless message
    m = message.downcase
    if contains_ticket?(m)
      SlackbotFrd::Log.info("User '#{user}' is opening an IT ticket through Roy. message: '#{message}'")
      return process_ticket(user: user, message: message)
    elsif m.include?('roy') || m.include?('<!channel') || m.include?('<!group') || m.include?('<!here')
      return "Hello, IT, have you tried turning it off and on again?\n\n" \
             "If you need me to open a ticket for you, type something like: \n" \
             "```#{OPEN_EXAMPLE}```"
    elsif m =~ /ticket/ && ((m =~ /file/) || (m =~ /is/ && m =~ /there/) || (m =~ /submit/) || (m =~ /open/)) && time_expired?
      capture_time
      # submit ticket
      # open ticket
      # file ticket
      # is there ticket
      return "No ticket?\n\nhttp://i.imgur.com/avwx7Zj.gif\nhttp://media.giphy.com/media/CHROEms0iVuda/giphy.gif\n\nYou can open a ticket through me by typing something like:\n```#{OPEN_EXAMPLE}```"
    end
    nil
  end

  def process_ticket(user:, message:)
    summary = ticket_summary(message)
    SlackbotFrd::Log.debug("User '#{user}' provided summary '#{summary}' from message '#{message}'")
    return "Can't open a ticket with a blank summary!" if summary.empty?
    issue = Jira::Issue.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    ).create(
      project: 'ITSD',
      issue_type: 'Service Request',
      summary: summary,
      description: "Request opened by slack user '#{user}' through Roy"
    )
    SlackbotFrd::Log.debug("Jira issue creation return val: '#{issue}'")
    if issue.key?('key')
      return "Excellent!  I opened up <#{jira_link_url(issue['key'])}|#{issue['key']}> for you"
    else
      SlackbotFrd::Log.warn("Problem creating issue in jira: '#{issue}'")
      return ":doh: something went wrong :nope: .  I guess you have " \
             "to do it manually.  Go to http://servicedesk.instructure.com " \
             "and click the 'IT Support' button."
    end
  end

  def jira_link_url(key)
    "https://instructure.atlassian.net/browse/#{key}/"
  end

  def time_expired?
    return true unless File.exist?(TIME_FILE)
    mins_45 = (60 * 45)
    (JSON.parse(File.read(TIME_FILE))["time"] + mins_45) <= Time.now.to_i
  end

  def capture_time
    File.write(TIME_FILE, { time: Time.now.to_i }.to_json)
  end
end
