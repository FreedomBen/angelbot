require 'slackbot_frd'
require 'net/http'
require 'uri'

class BitcoinBot < SlackbotFrd::Bot
  def endpoint
    'https://blockchain.info/ticker'
  end

  def cur_value
    JSON.parse(Net::HTTP.get_response(URI.parse(endpoint)).body)
  end

  def value_to_string(value)
    # "Currently:  *1* BTC == $ *#{value['USD']['last']}* _USD_\n     $ *#{value['AUD']['last']}* _AUD_ || #{value['EUR']['symbol']} *#{value['EUR']['last']}* _EUR_ || $ *#{value['CAD']['last']}* _CAD_"
    "Currently:  *1* BTC == $*#{value['USD']['last']}* _USD_"
  end

  def contains_trigger(message)
    message =~ /:(bitcoin|btc):/i
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'angel' && timestamp != thread_ts && contains_trigger(message)
        SlackbotFrd::Log.info("Fetching bitcoin value for user '#{user}' in channel '#{channel}'")
        slack_connection.send_message(
          channel: channel,
          message: value_to_string(cur_value),
          thread_ts: thread_ts,
          username: 'Bitcoin Bot',
          avatar_emoji: ':bitcoin:'
        )
      end
    end
  end
end
