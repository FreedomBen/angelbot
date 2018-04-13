require 'slackbot_frd'
require 'securerandom'

require_relative '../lib/jira/search'
require_relative '../lib/gerrit/change'
require_relative './gerrit-jira-translator'

require_relative '../lib/gerrit-jira-translator/data'

class Feedback < SlackbotFrd::Bot
  GERRIT_ID_FIELD = "customfield_10403"

  def contains_trigger(message)
    message =~ /(!feedback)/i
  end

  def feedback_jql(project)
    "project = #{project} AND status = Feedback ORDER BY updated ASC"
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'angel' && timestamp != thread_ts && contains_trigger(message)
        handle_feedback_jiras(slack_connection, user, channel, message, thread_ts)
      end
    end
  end

  def handle_feedback_jiras(slack_connection, user, channel, message, thread_ts)
    parser = GerritJiraTranslator.new
    search_api = Jira::Search.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    )
    /!feedback\s+(.+)$/i.match(message) do |matches|
      matches[1].split.each do |project|
        if project =~ /#{parser.whitelisted_prefixes}/i
          issues = search_api.get feedback_jql(project)
          slack_connection.send_message(
            channel: channel,
            message: parse_issues(issues),
            parse: 'full',
            thread_ts: thread_ts
          )
        end
      end
    end
  end

  def parse_issues(issues_json)
    messages = []
    issues = issues_json["issues"]
    issues.each do |issue|
      f = issue["fields"]
      messages << "#{issue["key"]} - #{f["summary"]}\nAssignee: #{f["assignee"]["displayName"]}\nPriority: #{f["priority"]["name"]}"
    end
    messages.join("\n")
  end
end
