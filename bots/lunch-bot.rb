require 'slackbot_frd'
require 'securerandom'

require_relative '../lib/lunch/search'

class LunchBot < SlackbotFrd::Bot

  def contains_trigger(message)
    message =~ /(!lunch)/i
  end

  def does_not_contain(message)
    !(message =~ /(template)/i && message =~ /(example)/i)
  end

  def send_invalid_command_error(slack_connection, channel, thread_ts)
    slack_connection.send_message(
        channel: channel,       
        message: "*Template:* !lunch <distance in miles> <cost in $-$$$$> \n *Example:* !lunch 5 $$",
        parse: 'none',
        thread_ts: thread_ts
    )
  end

  def parse_url(url)
    url.split("?")[0]
  end

  def edit_url(url)
    url.sub('biz', "map")
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != 'angel' && timestamp != thread_ts && contains_trigger(message) && does_not_contain(message)
        handle_lunch_request(slack_connection, user, channel, message, thread_ts)
      end
    end
  end

  def handle_lunch_request(slack_connection, user, channel, message, thread_ts)
        message.slice! "!lunch"
        if message == "" 
            send_invalid_command_error(slack_connection, channel, thread_ts)
        else
            message = message.split(" ")
            if message.count != 2
                send_invalid_command_error(slack_connection, channel, thread_ts)
                return
            end
            distance = message[0].to_i
            cost = message[1].length
            search_api = Lunch::Search.new
            if distance > 24
                distance = 24
            end
            if cost > 4
                cost = 4
            end
            restaurant_list = search_api.get(distance, cost)
            slack_connection.send_message(
                channel: channel,
                message: parse_places(restaurant_list),
                parse: 'none',
                thread_ts: thread_ts
            )
        end  
    end

  def parse_places(restaurants)
    if restaurants['total'] > 0
        random = rand(restaurants['businesses'].length)
        response = []
        response << "<#{parse_url(restaurants['businesses'][random]['url'])}|*#{restaurants['businesses'][random]['name']}*>"
        response << "*Directions:* <#{edit_url(restaurants['businesses'][random]['url'])}|:oncoming_automobile:>"
        response << "*Rating*: #{restaurants['businesses'][random]['rating']}"
        type = []
        restaurants['businesses'][random]['categories'].each do |category|
            type << "#{category["title"]}"
        end
        response << "*Type:* #{type.join(", ")}"
        response.join("\n")
    else
        "Looks like there aren't any places that match your criteria :sherlock:"
    end
  end
end
