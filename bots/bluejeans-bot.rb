require 'slackbot_frd'
require 'json'

class BluejeansBot < SlackbotFrd::Bot
  # Because this information can be sensitive, it is sourced
  # from an external file called 'bluejeans-meetings.json'
  BLUEJEANS = JSON.parse(File.read('data/bluejeans-meetings.json'))

  BJ_PHONE = %w[
    1.888.240.2560
    1.408.740.7256
    1.408.317.9253
  ]

  QUIET_CHANNEL_MIN_USERS = 15

  ALWAYS_QUIET_CHANNELS = %w[
    eng
    canvas-eng
    instructure
    it
    security
    service_delivery
    bps_test_graveyard
  ]

  BLUEJEANS_EXTRACT = /^(:?bluejeans:?|bj)\s/i

  def bj_url(id)
    "https://bluejeans.com/#{id}"
  end

  def assembled_message(room_name:, room_id:, link:)
    "*#{room_name}*: :bluejeans: #{bj_url(link)}\n" \
    "     Meeting ID: #{room_id}"
  end

  def bluejeans?(message)
    message =~ BLUEJEANS_EXTRACT
  end

  def regex_in(message)
    message.gsub(BLUEJEANS_EXTRACT, '').gsub(/\s/, '\s')
  end

  def lenient_room(room)
    room.gsub(/\W/, '.')
  end

  def lenient_regex(regex)
    regex.gsub(/\W/, '.?')
  end

  def room_matches_strict(room, regex)
    regex =~ /all/i || room =~ /#{regex}/i
  end

  def room_matches_lenient(room, regex)
    room_matches_strict(lenient_room(room), lenient_regex(regex))
  end

  def room_matches(room, regex)
    room_matches_strict(room, regex) || room_matches_lenient(room, regex)
  end

  def quiet_channel?(slack_connection, channel)
    # if there are more than QUIET_CHANNEL_MIN_USERS in the channel, it is a "quiet" channel
    ALWAYS_QUIET_CHANNELS.include?(channel) ||
      slack_connection.num_users_in_channel(channel) > QUIET_CHANNEL_MIN_USERS
  end

  def notify_of_dm(slack_connection, channel, thread_ts)
    slack_connection.send_message(
      channel: channel,
      message: "Listing all :bluejeans: links in this channel is a bit noisy.  I'll DM you :wink:",
      thread_ts: thread_ts
    )
  end

  def notify_of_no_match(slack_connection, channel, regex, thread_ts)
    slack_connection.send_message(
      channel: channel,
      message: "Sorry, no conference rooms matched the regular expression '#{regex}'",
      thread_ts: thread_ts
    )
  end

  def send_info(slack_connection, channel, k, quiet, thread_ts)
    room_id = BLUEJEANS[k]['number']
    link = if BLUEJEANS[k]['link'].empty?
             room_id
           else
             "instructure.#{BLUEJEANS[k]['link']}"
           end
    slack_connection.send_message(
      channel: channel,
      message: assembled_message(
        room_name: k,
        room_id: room_id,
        link: link
      ),
      channel_is_id: quiet,
      thread_ts: thread_ts
    )
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'angel' && bluejeans?(message)
        SlackbotFrd::Log.info(
          "Bluejeans bot: request for '#{message}' from user '#{user}' in channel '#{channel}'"
        )

        # ignore messages with more than 4 words
        unless message.split(' ').count > 3
          SlackbotFrd::Log.info(
            "Bluejeans bot skipping message due to 4 or more words (count is #{message.split(' ').count})"
          )

          regex = regex_in(message)
          found = false
          quiet = false

          if (regex =~ /all/i || regex == '.*') && quiet_channel?(slack_connection, channel)
            quiet = true
            notify_of_dm(slack_connection, channel)
            channel = slack_connection.im_channel_for_user(user: user)
          end

          BLUEJEANS.each_key do |k|
            if room_matches(k, regex)
              found = true
              send_info(slack_connection, channel, k, quiet, thread_ts)
            end
          end

          notify_of_no_match(slack_connection, channel, regex, thread_ts) unless found
        end
      end
    end
  end
end
