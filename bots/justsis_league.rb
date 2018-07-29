require "slackbot_frd"
require "securerandom"

class Justsis_League < SlackbotFrd::Bot
  TRIGGER = /SIS-(NUCLEAR|HIGH|MEDIUM)/i

  def contains_trigger(message)
    message =~ TRIGGER
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != "angel" && timestamp != thread_ts && contains_trigger(message)
        SlackbotFrd::Log.info("Trigger found: '#{message}'. Parsing.")
        handle_trigger(slack_connection, user, channel, message, thread_ts)
      end
    end
  end

  def handle_trigger(slack_connection, _user, channel, message, thread_ts)
    TRIGGER.match(message) do |matches|
      matches[1].split.each do |priority|
        priority.gsub!(/[^\w\s]/, "")
        SlackbotFrd::Log.info("Priority for justsis_league trigger: #{priority}")
        next unless priority.upcase =~ /(NUCLEAR|HIGH|MEDIUM)/

        case priority.upcase
        when "NUCLEAR"
          message = "There is a major outage with SIS and clients in mass are affected (e.g. all grades, all provisioning, etc.) - please respond immediately @oxana @mcotterman and @cdonio!"
          image = "http://a.grim.rip/qyAh"
        when "HIGH"
          message = "There is an issue affecting several clients (e.g. a release or bug is impacting numerous clients) - @oxana @mcotterman and @cdonio I need your help determining if an escalation is necessary."
          image = "http://a.grim.rip/qxR3"
        when "MEDIUM"
          message = "Heads up @oxana @mcotterman and @cdonio! I need your help with a client or small number of clients that need de-escalation (i.e. there's the potential that more customers will be affected)."
          image = "http://a.grim.rip/qwom"
        end

        slack_connection.send_message(
          channel: channel,
          message: format_message(message, image),
          parse: "full",
          thread_ts: thread_ts,
        )
      end
    end
  end

  def format_message(message, image)
    "#{message}\n\n#{image}"
  end
end
