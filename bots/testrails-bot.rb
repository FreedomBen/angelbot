require 'slackbot_frd'
require 'securerandom'

require_relative '../lib/testrails/user'

require_relative '../lib/gerrit-jira-translator/data' #used for channel values

class TestrailsBot < SlackbotFrd::Bot

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'angel' && timestamp != thread_ts
        if contains_testrails(message)
          handle_testrails(slack_connection, user, channel, message, thread_ts, false)
        elsif contains_testrails_url(message)
          handle_testrails(slack_connection, user, channel, message, thread_ts, true)
        end
      end
    end
  end

  def handle_testrails(slack_connection, user, channel, message, thread_ts, found_url)
    translate_testrails(slack_connection, user, channel, message, thread_ts, found_url)
  end

  def translate_testrails(slack_connection, user, channel, message, thread_ts, found_url)
    if found_url
      extracted_testrails = extract_testrailcases_from_url(message)
    else
      extracted_testrails = extract_testrailcases(message)
    end

    if extracted_testrails.count == 1
      translate_single_testrails(extracted_testrails.first, slack_connection, user, channel, message, thread_ts)
    else
      translate_multiple_testrails(extracted_testrails, slack_connection, user, channel, message, thread_ts)
    end
  end

  def translate_single_testrails(extracted_testrail, sc, user, channel, message, thread_ts)
    change_api = Testrails::Change.new(
      username: $slackbotfrd_conf["testrail_username"],
      password: $slackbotfrd_conf["testrail_password"]
    )
    data = GerritJiraData.new(channel: channel)
    log_info("Translated C#{extracted_testrail} for user '#{user}' in channel '#{channel}'")

    msg = build_single_line_testrail_str(extracted_testrail, change_api, data)
    send_msg(sc: sc, channel: channel, message: msg, parse: 'none', thread_ts: thread_ts)
  end

  def translate_multiple_testrails(extracted_testrails, sc, user, channel, message, thread_ts)
    change_api = Testrails::Change.new(
      username: $slackbotfrd_conf["testrail_username"],
      password: $slackbotfrd_conf["testrail_password"]
    )
    data = GerritJiraData.new(channel: channel)
    testrails = extracted_testrails.map do |tr|
      log_info("Translated multiple C#{tr} for user '#{user}' in channel '#{channel}'")
      build_single_line_testrail_str(tr, change_api, data)
    end
    send_msg(sc: sc, channel: channel, message: testrails.join("\n"), parse: 'none', thread_ts: thread_ts)
  end

  def log_info(message)
    begin
      SlackbotFrd::Log.info(message)
    rescue IOError => e
    end
  end

  def testrail_url(testrail_id)
    "https://canvas.testrail.com/index.php?/cases/view/#{testrail_id}/"
  end

  def extract_testrailcases(str)
    str.scan(/c(\d{5,9})/i).map{ |a| a.first }.uniq
  end

  def contains_testrails(str)
    str.downcase =~ /(^|\s|\()c\d{5,9}[.!?,;)\/]*($|\s)/i
  end

  def extract_testrailcases_from_url(str)
    str.scan(/cases\/view\/(\d{5,9})/i).map{ |a| a.first.sub('/cases\/view\/', '') }.uniq
  end

  def contains_testrails_url(str)
    str.downcase =~ /(^|\s|\()[htps.:\/<]*canvas\.testrail\.com\/index\.php\?\/cases\/view\/\d{5,9}[\S>]*($|\s)/i
  end

  def fix_priority(id)
    case id
    when 1
      return ':p: :three:'
    when 3
      return ':p: :two:'
    when 4
      return ':p: :one:'
    when 6
      return ':p: :smokey:'
    when 7
      return ':p: STUB'
    else
      return -1
    end
  end

  def build_single_line_testrail_str(testrail_id, change_api, data)
    begin
      result = change_api.get_testcase(testrail_id)

      title = result['title']
      title = title.first(30) + "..." if title.length > 30
      priority = fix_priority(result['priority_id'])
      section_id = result['section_id']
      location = change_api.get_sections(section_id)
      already_automated = result['custom_automated'] ? ':yes:' : ':nope:'
      # to_be_automated = result['custom_to_be_automated']

      if data.channel_full?
        return  "Test :rails: <#{testrail_url(testrail_id)}|C#{testrail_id}> - #{priority}" \
                "          *Title:*  #{title}\n" \
                "          *Automated?* #{already_automated}" \
                "          *Path:*  #{location}"
      else
        return "Test :rails: :  <#{testrail_url(testrail_id)}|C#{testrail_id}> - [#{title}] - #{priority} - *Automated?* #{already_automated} -*Path:* #{location}"
      end
    rescue StandardError => e
      SlackbotFrd::Log.warn(
        "Error encountered parsing testrail #{testrail_id}'.  " \
        "Message: #{e.message}.\n#{e}"
      )
      return "Test :rails: :  <#{testrail_url(testrail_id)}|C#{testrail_id}> - #{result} - I don't think that's a valid test case number"
    end
  end

  private

  def pick_bot
    num = SecureRandom.random_number(160)

    return :devil   if num == 1
    return :weeping if [2, 3].include?(num)
    :angel
  end

  def send_msg(sc:, channel:, message:, parse: 'full', thread_ts: nil)
    return if message.empty?

    bot = pick_bot
    if channel == 'it'
      sc.send_message(
        channel: channel,
        message: message,
        parse: parse,
        username: 'Roy',
        avatar_emoji: ':roy:',
        thread_ts: thread_ts
      )
    elsif channel == 'pandata'
      sc.send_message(
        channel: channel,
        message: message,
        parse: parse,
        username: 'Moss',
        avatar_emoji: ':moss:',
        thread_ts: thread_ts
      )
    elsif bot == :devil
      sc.send_message(
        channel: channel,
        message: message,
        parse: parse,
        username: 'Devil Bot',
        avatar_emoji: ':devil:',
        thread_ts: thread_ts
      )
    elsif bot == :weeping
      sc.send_message(
        channel: channel,
        message: message,
        parse: parse,
        username: 'Weeping Angel Bot',
        avatar_emoji: ':weeping-angel:',
        thread_ts: thread_ts
      )
    else
      sc.send_message(
        channel: channel,
        message: message,
        parse: parse,
        thread_ts: thread_ts
      )
    end
  end
end
