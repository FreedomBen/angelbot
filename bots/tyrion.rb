require 'slackbot_frd'
require 'fuzzy_match'

class Tyrion < SlackbotFrd::Bot
  OPEN_EXAMPLE = 'tyrion: ticket to <summary of the problem>'.freeze
  TICKET_REGEX = /^tyrion:?\s+(?:open)?\s*ticket\s+(?:to|for)\s+(.*)/i

  def desired_channel?(channel)
    %w[security secops secteam-core bps_test_graveyard bps_test_graveyard2].include?(channel)
  end

  def contains_jiras(str)
    str.downcase =~ /(^|\s)\(?SEC-\d{1,9}\)?[.!?,;)]*($|\s)/i
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && desired_channel?(channel) && user != :bot && timestamp != thread_ts
        resp = response(sc: slack_connection, user: user, message: message)
        if resp
          slack_connection.send_message(
            channel: channel,
            message: resp,
            username: 'Tyrion',
            avatar_emoji: ':tyrion:',
            parse: contains_ticket?(message) ? 'none' : 'full',
            thread_ts: thread_ts
          )
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
      SlackbotFrd::Log.info("User '#{user}' is opening a Security ticket through Tyrion. message: '#{message}'")
      return process_ticket(sc: sc, user: user, message: message)
    elsif m =~ /thanks?(\syou)?\s+tyrion/i || m =~ /tyrion:?\sthanks?(\syou)?/i || m =~ /thx\s+tyrion/i
      return "You're very welcome, #{user}!"
    elsif m =~ /ticket/ && ((m =~ /file/) || (m =~ /is/ && m =~ /there/) || (m =~ /submit/) || (m =~ /open/) || (m =~ /send/))
      return "Need to open a ticket?  You can open a ticket at through me by typing:\n```#{OPEN_EXAMPLE}```"
    end
    nil
  end

  def process_ticket(sc:, user:, message:)
    summary = ticket_summary(message)
    SlackbotFrd::Log.debug("User '#{user}' provided summary '#{summary}' from message '#{message}'")
    return "Can't open a ticket with a blank summary!" if summary.empty?
    issue_type = 'Task'
    user_info = OpenStruct.new(sc.user_info(user)['profile'])

    user_api = Jira::User.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    )
    reporting_user = user_api.search(user_info.email)
    reporting_user = nil if !reporting_user || reporting_user.count != 1
    reporting_user = reporting_user.first['name'] if reporting_user
    SlackbotFrd::Log.debug("Slack user '#{user}' has jira name '#{reporting_user}'")
    description = "Request opened by slack user '#{user}' through Tyrion.  This user's jira username is '#{reporting_user}' and their email address is '#{user_info.email}'"

    begin
      issue = Jira::Issue.new(
        username: $slackbotfrd_conf['jira_username'],
        password: $slackbotfrd_conf['jira_password']
      ).create(
        project: 'SEC',
        issue_type: issue_type,
        summary: summary,
        description: description,
        # can't do reporter_name for now, likely due to permissions missing:
        # https://answers.atlassian.com/questions/265902/create-issue-getting-error-on-reporter-field-reporter-cannot-be-set
        # reporter_name: reporting_user
      )
      SlackbotFrd::Log.debug("Jira issue creation under issue type '#{issue_type}' return val: '#{issue}'")
      if issue.key?('key')
        return "Success!  I opened up <#{jira_link_url(issue['key'])}|#{issue['key']}> " \
        "for you under Issue Type '#{issue_type}'."
        reassign_reporter
      else
        SlackbotFrd::Log.warn("Problem creating issue under issue type '#{issue_type}' in jira: '#{issue}'")
        return ":doh: :nope: sorry #{user}, something went wrong when opening issue type '#{issue_type}'.  You can " \
               'do it manually.  Go to http://servicedesk.instructure.com ' \
               "and click the 'IT Support' button.\n\nTechnical information:\n\n" \
               "```#{issue}```"
      end
    rescue Net::ReadTimeout
      SlackbotFrd::Log.warn("Problem creating issue under issue type '#{issue_type}' in jira for user '#{user}' email '#{reporting_user}'")
      return "Oh no!  Sorry #{user}.  :jira: timed out on us.  _Your ticket " \
             'may have been created even tho Jira never responded_ (it ' \
             'does that sometimes).  You might want to wait for Jira to ' \
             'come back and then try again.  You can also try to ' \
             'do it manually by going to http://servicedesk.instructure.com ' \
             "and clicking the 'IT Support' button."
    end
  end

  def jira_link_url(key)
    "https://instructure.atlassian.net/browse/#{key}"
  end
end
