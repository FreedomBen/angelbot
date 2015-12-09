require 'slackbot_frd'

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
    extract_gerrits(message).each do |gn|
      slack_connection.send_message(channel: channel, message: "g/#{gn} is #{gerrit_url(gn)}")
      log_info("Translated g/#{gn} for user '#{user}' in channel '#{channel}'")
    end
  end

  def translate_jiras(slack_connection, user, channel, message)
    extract_jiras(message).each do |jira|
      slack_connection.send_message(
        channel: channel,
        message: "#{jira[:prefix]}-#{jira[:number]} is #{jira_url(jira[:prefix], jira[:number])}"
      )
      log_info("Translated #{jira[:prefix]}-#{jira[:number]} for user '#{user}' in channel '#{channel}'")
    end
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
    str.scan(/(CNVS|TD)-(\d+)/i).map do |prefix, num|
      { prefix: prefix.upcase, number: num }
    end.uniq
  end

  def contains_gerrits(str)
    # g/12345
    str.downcase =~ /(^|\s)g\/\d{3,9}[.!?,;]*($|\s)/i
  end

  def contains_jiras(str)
    # CNVS-12345 || TD-12345
    str.downcase =~ /(^|\s)(CNVS|TD)-\d{1,9}[.!?,;]*($|\s)/i
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
