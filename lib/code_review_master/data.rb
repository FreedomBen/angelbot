require_relative '../dynamo'
require_relative '../gerrit/change'

require_relative './message_segment'
require_relative './user'

module CodeReviewMaster
  class Data
    def initialize(channel, slack_username)
      @channel = channel
      @slack_username = slack_username
    end

    def add_reviewer!(segment)
      begin
        user = CodeReviewMaster::MessageSegment.new(segment).to_user
        return user if reviewers.map(&:values).flatten.any? { |name| user.to_h.values.include?(name) }
        return user if (config['reviewers'] << user.to_h && save!)
      rescue CodeReviewMaster::MessageSegment::ParseError => e
        SlackbotFrd::Log.debug(
          "Failed to parse user segnment: #{segment}"
        )
        false
      end
    end

    def assign_reviewer!(change_id)
      dup_reviewers = reviewers.dup
      slack_user_index = dup_reviewers.index do |reviewer|
        reviewer['slack'] == slack_username
      end
      if slack_user_index != 0
        assigned = dup_reviewers.shift
      else
        assigned = dup_reviewers.slice!(1)
      end

      dup_reviewers << assigned
      self.reviewers = dup_reviewers
      save!
      CodeReviewMaster::User.new(assigned)
    end

    def clear_reviewers!
      self.reviewers = []
      save!
    end

    def persist_to_gerrit!(change_id:, assigned:)
      if change_api
        begin
          change_api.add_reviewer(
            id: change_id,
            account_id: assigned.gerrit_username
          )
        rescue StandardError => e
          SlackbotFrd::Log.warn(
            "Error encountered sending reviewer to gerrit #{change_id}'.  " \
            "Message: #{e.message}.\n#{e}"
          )
          false
        end
      else
        SlackbotFrd::Log.warn(
          "Gerrit is not configured."
        )
        false
      end
    end

    def remove_reviewer!(name)
      SlackbotFrd::Log.warn(
        "Remove reviewer name: #{name} " \
        "#{reviewers.map(&:values).flatten}"
      )
      return true unless reviewers.map(&:values).flatten.include?(name)
      return true if config['reviewers'].delete_if do |reviewer|
        reviewer.values.include?(name)
      end && save!
      false
    end

    def reviewers
      config['reviewers']
    end

    def users
      reviewers.map {|reviewer| CodeReviewMaster::User.new(reviewer) }
    end

    private
    attr_reader :channel, :slack_username

    def change_api
      return nil unless gerrit_configured?

      @_change_api ||= Gerrit::Change.new(
        username: $slackbotfrd_conf['gerrit_username'],
        password: $slackbotfrd_conf['gerrit_password']
      )
    end

    def config
      unless @_config
        item = db.get_item(
          table: table_name,
          primary: channel
        ).item
        @_config = (item || {
          'reviewers' => []
        })
      end
      @_config
    end

    def db
      unless @_db
        @_db = DynamoDB.new(botname: 'angelbot')
        @_db.create_table(table_name, if_not_exist: true)
      end
      @_db
    end

    def gerrit_configured?
      $slackbotfrd_conf['gerrit_username'] && $slackbotfrd_conf['gerrit_password']
    end

    def reviewers=(new_reviewers)
      config['reviewers'] = new_reviewers
    end

    def save!
      db.put_item(
        table: table_name,
        primary: channel,
        attrs: config
      )
    end

    def table_name
      "code_review_master_channel_settings"
    end
  end
end
