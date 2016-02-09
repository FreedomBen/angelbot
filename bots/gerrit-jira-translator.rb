require 'slackbot_frd'

require_relative '../lib/jira/issue'

class GerritJiraTranslator < SlackbotFrd::Bot
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

      build_jira_str(jira, issue_api.get(jira[:id]))
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
    str.scan(/(CNVS|TD|MBL|OPS|SD|RD|ITSD)-(\d+)/i).map do |prefix, num|
      { id: "#{prefix.upcase}-#{num}", prefix: prefix.upcase, number: num }
    end.uniq
  end

  def contains_gerrits(str)
    # g/12345
    str.downcase =~ /(^|\s)g\/\d{3,9}[.!?,;]*($|\s)/i
  end

  def contains_jiras(str)
    # CNVS-12345 || TD-12345 || MBL-432 || OPS || SD || RD || ITSD
    str.downcase =~ /(^|\s)\(?(CNVS|TD|MBL|OPS|SD|RD|ITSD)-\d{1,9}\)?[.!?,;]*($|\s)/i
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

  def build_jira_str(jira, issue)
    comp_str = ->() do
      title = '          *Component(s)*:  '
      component_str(issue).empty? ? "" : "#{title}#{component_str(issue)}\n"
    end

    "#{jira_string_header(jira, issue)}" \
    "          *Summary:*  #{summary_str(issue)}\n" \
    "#{comp_str.call}" \
    "          *Status:*  #{status_str(issue)}\n" \
    "          *Assigned to*:  #{assigned_to_str(issue)}"
  end

  def story_points(issue)
    issue["fields"] && issue["fields"]["customfield_10004"] && issue["fields"]["customfield_10004"].to_s
  end

  def story_points_str(issue)
    story_points_to_emoji(story_points(issue)) || ''
  end

  def priority_str(issue)
    if issue["fields"] && issue["fields"]["priority"] && issue["fields"]["priority"]['name']
      priority_to_emoji(issue["fields"]["priority"]["name"]) || ''
    else
      ''
    end
  end

  def priority_to_emoji(priority)
    {
      "maintenance" => ":jira_maintenance_priority:",
      "pressing"    => ":jira_pressing_priority:",
      "critical"    => ":jira_critical_priority:",
    }[priority.downcase]
  end

  def story_points_to_emoji(points)
    {
      "2.0" => ":2storypoints:",
      "3.0" => ":3storypoints:",
      "5.0" => ":5storypoints:",
      "8.0" => ":8storypoints:",
      "13.0" => ":13storypoints:",
    }[points]
  end

  def summary_str(issue)
    issue["fields"] && issue["fields"]["summary"]
  end

  def component_str(issue)
    if issue["fields"] && issue["fields"]["components"]
      issue["fields"]["components"].map{|c| c["name"]}.join(", ")
    else
      ''
    end
  end

  def status_str(issue)
    retval = if issue['fields'] && issue["fields"]["status"]
               issue["fields"]["status"]["name"]
             else
               ''
             end
    retval.empty? ? 'Not set' : retval
  end

  def assigned_to_str(issue)
    retval = if issue["fields"] && issue["fields"]["assignee"]
               issue["fields"]["assignee"]["displayName"]
             else
               ''
             end
    retval.empty? ? 'Unassigned' : retval
  end

  def jira_string_header(jira, issue)
    ":jira: #{jira_link(jira)}  " \
    "#{priority_str(issue)}  #{story_points_str(issue)}\n" \
  end

  def jira_link(jira)
    "<#{jira_link_url(jira)}|#{jira_link_text(jira)}>"
  end

  def jira_link_url(jira)
    jira_url(jira[:prefix], jira[:number])
  end

  def jira_link_text(jira)
    "#{jira[:prefix]}-#{jira[:number]}"
  end
end
