require 'slackbot_frd'
require 'securerandom'

require_relative '../lib/jira/search'
require_relative '../lib/gerrit/change'
require_relative './gerrit-jira-translator'

require_relative '../lib/gerrit-jira-translator/data'

class JiraBot < SlackbotFrd::Bot
  GERRIT_ID_FIELD = "customfield_10403"
  TEAM_FIELD = "customfield_12700"

  def contains_trigger(message)
    message =~ /(!jira)/i
  end

  def jira_jql(project, status)
    "project = #{project} AND status = \"#{status}\" ORDER BY updated ASC"
  end

  def jira_fields
    "#{GERRIT_ID_FIELD},#{TEAM_FIELD},summary,assignee,priority"
  end

  def send_message(slack_connection, channel, thread_ts, message)
    slack_connection.send_message(
        channel: channel,
        message: message,
        parse: 'none',
        thread_ts: thread_ts
    )
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != 'angel' && timestamp != thread_ts && contains_trigger(message)
        handle_jiras(slack_connection, user, channel, message, thread_ts)
      end
    end
  end

  def handle_jiras(slack_connection, user, channel, message, thread_ts)
    message.slice! "!jira"
    search_api = Jira::Search.new(
        username: $slackbotfrd_conf['jira_username'],
        password: $slackbotfrd_conf['jira_password']
    )

    # `!jira {"project": "BR", "team": "panama", "status": [ "QA Ready"]}`
    params = JSON.parse(message)

    if !params['project'] || !params['status']
      send_message(slack_connection, channel, thread_ts,
                   "*Invalid command. Example:* `!jira {\"project\": \"BR\", \"team\": \"panama\", \"status\": [ \"QA Ready\"]}`")
    end

    params['status'].each do |status|
      issues = search_api.get(jira_jql(params['project'], status), jira_fields)
      if issues['errorMessages']
        send_message(slack_connection, channel, thread_ts, "*Invalid project or status.*")
      else
        send_message(slack_connection, channel, thread_ts, parse_issues(params, issues, status))
      end
    end
  end

  def parse_issues(params, issues_json, status)
    parser = GerritJiraTranslator.new
    messages = []
    issues = issues_json["issues"]
    SlackbotFrd::Log.info(issues)
    messages << "*#{status}*"
    issues.each do |issue|
      f = issue["fields"]
      if params['team']
        expected_team = params['team']
        actual_team = f[TEAM_FIELD]['value']
        if expected_team.casecmp(actual_team) != 0
          next
        end
      end
      SlackbotFrd::Log.info("Parsing issue:")
      SlackbotFrd::Log.info(issue)
      jira = {prefix: issue["key"].split("-").first, number: issue["key"].split("-").last}
      messages << "#{parser.priority_str(issue)} #{parser.jira_link(jira)} - #{f["summary"]}"
      messages << "*Assigned to*: #{parser.assigned_to_str(issue)}"
      if f[GERRIT_ID_FIELD]
        gerrits = f[GERRIT_ID_FIELD]
                      .split
                      .select {|s| s =~ /http/}
                      .map {|url| url.split("/").last}
        gerrits.each do |gerrit|
          messages << ":gerrit: :  <#{parser.gerrit_url(gerrit)}|g/#{gerrit}> : <#{parser.gerrit_mobile_url(gerrit)}|:iphone:>"
        end
      end
      messages << "\n"
    end
    messages << "No issues awaiting feedback found for #{params['project']}" if messages.empty?
    messages.join("\n")
  end
end