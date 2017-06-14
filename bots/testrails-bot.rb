require 'slackbot_frd'
require 'securerandom'

require_relative '../lib/testrails/user'

class TestrailsBot < SlackbotFrd::Bot

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'angel' && timestamp != thread_ts
        if contains_command(message)
          handle_command(slack_connection, user, channel, message, thread_ts)
        elsif contains_testrails(message)
          handle_testrails(slack_connection, user, channel, message, thread_ts)
        end
      end
    end
  end

  def handle_testrails(slack_connection, user, channel, message, thread_ts)
    if contains_testrails(message)
      translate_testrails(slack_connection, user, channel, message, thread_ts)
    else
      SlackbotFrd::Log.debug(
        "Ignoring TestRails in channel '#{channel}' because " \
        'it has TestRails turned off'
      )
    end
  end

  def translate_testrails(slack_connection, user, channel, message, thread_ts)
    extracted_testrails = extract_testrailcases(message)
    if extracted_testrails.count == 1
      translate_single_testrails(extracted_testrails.first, slack_connection, user, channel, message, thread_ts)
    else
      translate_multiple_testrails(extracted_testrails, slack_connection, user, channel, message, thread_ts)
    end
  end

  def translate_single_testrails(extracted_testrail, sc, user, channel, message, thread_ts)
    change_api = Testrails::Change.new(
      username: $slackbotfrd_conf["testrail_username"],
      password: $slackbotfrd_conf["testrail_token"]
    )
    log_info("Translated C#{extracted_testrail} for user '#{user}' in channel '#{channel}'")

    msg = build_single_line_testrail_str(extracted_testrail, change_api)
    send_msg(sc: sc, channel: channel, message: msg, parse: 'none', thread_ts: thread_ts)
  end

  def translate_multiple_testrails(extracted_testrails, sc, user, channel, message, thread_ts)
    change_api = Testrails::Change.new(
      username: $slackbotfrd_conf["testrail_username"],
      password: $slackbotfrd_conf["testrail_token"]
    )
    testrails = extracted_testrails.map do |tr|
      log_info("Translated C#{tr} for user '#{user}' in channel '#{channel}'")
      build_single_line_testrail_str(tr, change_api)
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

  def testrails_url(testrail_num)
    "https://canvas.testrail.com/index.php?/cases/view/#{testrail_num}"
  end

  def testrails_urls(testrail_nums)
    testrail_nums.map{ |trn| testrails_url(trn) }
  end


  def build_single_line_testrail_str(testrail_id, change_api)
    begin
      change = change_api.get_testcase(testrail_id)
      title = change['title']
      title = title.first(30) + "..." if title.length > 30
      priority = change['priority_id']
      section_id = change['section_id']
      location = change_api.get_sections(section_id)

      # to_be_automated = change['custom_to_be_automated']
      already_automated = change['custom_automated'] ? ':yes:' : ':nope:'
      return "Test :rails: :  <#{testrail_url(testrail_id)}|C#{testrail_id}> - [#{title}] - *Priority:* #{priority} - *Automated?* #{already_automated} -*Path:* #{location}"
    rescue StandardError => e
      SlackbotFrd::Log.warn(
        "Error encountered parsing testrail #{testrail_id}'.  " \
        "Message: #{e.message}.\n#{e}"
      )
      return "Test :rails: :  <#{testrail_url(testrail_id)}|C#{testrail_id}> - _error reading status from testrails"
    end
  end

    private

  def command_regex
    /^\@?angel(bot)?:?\s+set\s+(\w+)\s+(\w+)/i
  end

  def read_settings_command_regex
    /^\@?angel(bot)?:?\s+settings/i
  end

  def contains_command(message)
    contains_read_settings_command(message) ||
      contains_set_settings_command(message)
  end

  def contains_read_settings_command(message)
    message =~ read_settings_command_regex
  end

  def contains_set_settings_command(message)
    message =~ command_regex
  end

  def command_key_val(message)
    message.match(command_regex).captures
  end

  def command_key(message)
    command_key_val(message)[0]
  end

  def command_val(message)
    command_key_val(message)[1]
  end

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
