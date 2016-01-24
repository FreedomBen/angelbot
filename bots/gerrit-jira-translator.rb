require 'slackbot_frd'

require_relative '../lib/jira/issue'

class GerritJiraTranslator < SlackbotFrd::Bot
  def priority_to_emoji(priority)
    {
      "maintenance" => ":jira_maintenance_priority:",
      "pressing"    => ":jira_pressing_priority:",
      "critical"    => ":jira_critical_priority:",
    }[priority.downcase]
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:|
      if message && user != :bot && user != 'angel'
        translate_gerrits(slack_connection, user, channel, message) if contains_gerrits(message)
        translate_jiras(slack_connection, user, channel, message)   if contains_jiras(message)
      end
    end
  end

  def translate_gerrits(slack_connection, user, channel, message)
    gerrits = extract_gerrits(message).map do |gn|
      log_info("Translated g/#{gn} for user '#{user}' in channel '#{channel}'")

      "<#{gerrit_url(gn)}|g/#{gn}>"
    end

    message = ":gerrit: :  #{gerrits.join('  |  ')}"

    slack_connection.send_message(channel: channel, message: message, parse: 'none')
  end

  def translate_jiras(slack_connection, user, channel, message)
    issue_api = Jira::Issue.new(
      username: $slackbotfrd_conf["jira_username"],
      password: $slackbotfrd_conf["jira_password"]
    )
    jiras = extract_jiras(message).map do |jira|
      log_info("Translated #{jira[:prefix]}-#{jira[:number]} for user '#{user}' in channel '#{channel}'")
      issue = issue_api.get(jira[:id])

      ":jira: <#{jira_url(jira[:prefix], jira[:number])}|#{jira[:prefix]}-#{jira[:number]}>  " \
      "#{priority_to_emoji(issue["fields"]["priority"]["name"]) || ''}\n" \
      "          *Summary:*  #{issue["fields"]["summary"]}\n" \
      "          *Component(s)*:  #{issue["fields"]["components"].map{|c| c["name"]}.join(", ")}\n" \
      "          *Status:*  #{issue["fields"]["status"]["name"]}\n" \
      "          *Assigned to*:  #{issue["fields"]["assignee"]["displayName"]}"
    end

    message = jiras.join("\n")

    slack_connection.send_message(channel: channel, message: message, parse: 'none') unless message.empty?
  end

  def log_info(message)
    begin
      SlackbotFrd::Log.info(message)
    rescue IOError => e
    end
  end

  def extract_gerrits(str)
    str.scan(/g\/(\d+)/i).map{ |a| a.first }.uniq
  end

  def extract_jiras(str)
    str.scan(/(CNVS|TD|MBL|OPS|SD|RD)-(\d+)/i).map do |prefix, num|
      { id: "#{prefix.upcase}-#{num}", prefix: prefix.upcase, number: num }
    end.uniq
  end

  def contains_gerrits(str)
    # g/12345
    str.downcase =~ /(^|\s)g\/\d{3,9}[.!?,;]*($|\s)/i
  end

  def contains_jiras(str)
    # CNVS-12345 || TD-12345 || MBL-432 || OPS || SD || RD
    str.downcase =~ /(^|\s)(CNVS|TD|MBL|OPS|SD|RD)-\d{1,9}[.!?,;]*($|\s)/i
  end

  def gerrit_url(gerr_num)
    "https://gerrit.instructure.com/#/c/#{gerr_num}/"
  end

  def gerrit_urls(gerr_nums)
    gerr_nums.map{ |gn| gerrit_url(gn) }
  end

  def jira_url(prefix, jira_num)
    "https://instructure.atlassian.net/browse/#{prefix.upcase}-#{jira_num}/"
  end

  def jira_urls(jira_nums)
    jira_nums.map{ |cn| jira_url(cn) }
  end
end
