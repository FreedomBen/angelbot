module CodeReviewMaster
  class Message
    def initialize(slack_connection:, channel:, thread_ts:)
      @slack_connection = slack_connection
      @channel = channel
      @thread_ts = thread_ts
    end

    def send_message(message)
      slack_connection.send_message(
        channel: channel,
        message: message,
        thread_ts: thread_ts
      )
    end

    private
    attr_reader :slack_connection, :channel, :thread_ts
  end
end
