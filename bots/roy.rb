require 'slackbot_frd'
require 'fuzzy_match'

class Roy < SlackbotFrd::Bot
  TIME_FILE = '/tmp/it-roybot-time-file.txt'
  OPEN_EXAMPLE = 'roy: ticket to <summary of the problem>'
  TICKET_REGEX = /^roy:?\s+(?:open)?\s*ticket\s+(?:to|for)\s+(.*)/i

  def desired_channel?(channel)
    #%w[it bps_test_graveyard bps_test_graveyard2].include?(channel)
    %w[bps_test_graveyard bps_test_graveyard2].include?(channel)
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:|
      if message && desired_channel?(channel) && user != :bot
        resp = response(sc: slack_connection, user: user, message: message)
        if resp
          slack_connection.send_message(
            channel: channel,
            message: resp,
            username: 'Roy',
            avatar_emoji: ':roy:',
            parse: contains_ticket?(message) ? 'none' : 'full'
          )
          #slack_connection.post_reaction(
          #  name: 'roy',
          #  channel: channel,
          #  timestamp: timestamp
          #)
        end
      end
    end
  end

  def contains_ticket?(message)
    message =~ TICKET_REGEX
  end

  def ticket_summary(message)
    message.match(TICKET_REGEX).captures.first
  end

  def response(sc:, user:, message:)
    return nil unless message
    m = message.downcase
    if contains_ticket?(m)
      SlackbotFrd::Log.info("User '#{user}' is opening an IT ticket through Roy. message: '#{message}'")
      return process_ticket(sc: sc, user: user, message: message)
    elsif m.include?('roy') || m.include?('<!channel') || m.include?('<!group') || m.include?('<!here')
      # return "Hello, IT, have you tried turning it off and on again?"
      return "Need to open a ticket?  You can open a ticket at http://servicedesk.instructure.com or through me by typing:\n```#{OPEN_EXAMPLE}```"
    elsif m =~ /ticket/ && ((m =~ /file/) || (m =~ /is/ && m =~ /there/) || (m =~ /submit/) || (m =~ /open/))# && time_expired?
      #capture_time
      # submit ticket
      # open ticket
      # file ticket
      # is there ticket
      #return "No ticket?\n\nhttp://i.imgur.com/avwx7Zj.gif\nhttp://media.giphy.com/media/CHROEms0iVuda/giphy.gif\n\nYou can open a ticket through me by typing something like:\n```#{OPEN_EXAMPLE}```"
      return "Need to open a ticket?  You can open a ticket at http://servicedesk.instructure.com or through me by typing:\n```#{OPEN_EXAMPLE}```"
    end
    nil
  end

  def process_ticket(sc:, user:, message:)
    summary = ticket_summary(message)
    SlackbotFrd::Log.debug("User '#{user}' provided summary '#{summary}' from message '#{message}'")
    return "Can't open a ticket with a blank summary!" if summary.empty?
    # issue_type = ticket_type(summary)
    issue_type = "Service Request - Other"
    user_info = OpenStruct.new(sc.user_info(user)['profile'])

    user_api = Jira::User.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    )
    reporting_user = user_api.search(user_info.email)
    reporting_user = nil if !reporting_user || reporting_user.count != 1
    reporting_user = reporting_user.first['name'] if reporting_user
    SlackbotFrd::Log.debug("Slack user '#{user}' has jira name '#{reporting_user}'")

    issue = Jira::Issue.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    ).create(
      project: 'ITSD',
      issue_type: issue_type,
      summary: summary,
      description: "Request opened by slack user '#{user}' through Roy"
    )
    SlackbotFrd::Log.debug("Jira issue creation under issue type '#{issue_type}' return val: '#{issue}'")
    if issue.key?('key')
      return "Excellent!  I opened up <#{jira_link_url(issue['key'])}|#{issue['key']}> " \
      "for you under Issue Type '#{issue_type}'."
      reassign_reporter
    else
      SlackbotFrd::Log.warn("Problem creating issue under issue type '#{issue_type}' in jira: '#{issue}'")
      return ":doh: :nope: sorry #{user}, something went wrong when opening issue type '#{issue_type}'.  You can " \
             "do it manually.  Go to http://servicedesk.instructure.com " \
             "and click the 'IT Support' button.\n\nTechnical information:\n\n" \
             "```#{issue}```"
    end
  end

  def reassign_reporter

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

  def ticket_types
    [
      'Service Request - Access',
      'Service Request - Email',
      'Service Request - Hardware',
      'Service Request - Network',
      'Service Request - Other',
      'Service Request - Phone',
      'Service Request - Software',
      'Service Request - Employee - New',
      'Service Request - Employee - Terminate',
      'Service Request - Employee - Transfer',
      'Service Request - Employee - Name Change/Update',
      'Service Request - Meeting Audio/Video Assistance',
      'Service Request - Site Admin',
      'Service Request - New Tier One Toll Free Number',
      'Service Request - Printer',
      'Service Request - First Day Equipment',
      'Audit Information Request (SOC2 / SOX)',
      'Application Access De-provision',
      'Application Access Provision',
      'Information Request',
      'Incident',
      'Other',
      'Purchase',
      'Purchase Request',
      'Problem',
      'Change'
    ]
  end

  def ticket_type(message)
    @fuzzy_match ||= FuzzyMatch.new(ticket_types)
    @fuzzy_match.find(message)
  end
end
