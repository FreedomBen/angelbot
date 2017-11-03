require 'slackbot_frd'
require 'net/http'
require 'uri'

class BitcoinBot < SlackbotFrd::Bot
  def inst_endpoint
    'https://api.iextrading.com/1.0/stock/inst/quote'
  end

  def endpoint
    'https://blockchain.info/ticker'
  end

  def cur_value
    JSON.parse(Net::HTTP.get_response(URI.parse(endpoint)).body)
  end

  def inst_value
    JSON.parse(Net::HTTP.get_response(URI.parse(inst_endpoint)).body)
  end

  def value_to_string(value)
    bitcoin_value = value['USD']['last']
    inst_shares_value = inst_value['latestPrice']
    "Currently:  *1* BTC == $*#{bitcoin_value}* _USD_ (or ~#{(bitcoin_value / inst_shares_value).ceil} shares of INST)"
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
