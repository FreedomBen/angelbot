require 'slackbot_frd'

require_relative '../lib/code_review_master/data'
require_relative '../lib/code_review_master/message'

class CodeReviewMasterBot < SlackbotFrd::Bot
  CODEREVIEWMASTER = 'codereviewmaster'

  ADD_COMMAND = 'add'
  CLEAR_COMMAND = 'clear'
  HELP_COMMAND = 'help'
  REMOVE_COMMAND = 'remove'
  LIST_COMMAND = 'list'

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if codereviewmaster?(user, message, channel, timestamp, thread_ts)
        data = CodeReviewMaster::Data.new(channel, user)
        m = CodeReviewMaster::Message.new(
          slack_connection: slack_connection,
          channel: channel,
          thread_ts: thread_ts
        )

        ################
        # Add reviewer #
        ################
        if (message_segment = add_reviewer_request?(message))
          SlackbotFrd::Log.debug(
            "user '#{user}' in channel '#{channel}' is adding reviewer with string #{message_segment}"
          )
          if (added_user = data.add_reviewer!(message_segment))
            m.send_message("Added #{added_user} to the list of reviewers :shipit:")
          else
            m.send_message("Can't add a user with string #{message_segment} :fail:")
          end
        end

        ###################
        # Remove reviewer #
        ###################
        if (to_remove = remove_reviewer_request?(message))
          SlackbotFrd::Log.debug(
            "user '#{user}' in channel '#{channel}' is adding the reviewer #{to_remove}"
          )
          if data.remove_reviewer!(to_remove)
            m.send_message("Removed #{to_remove} from the list of reviewers :shipit:")
          else
            m.send_message("Can't remove #{to_remove} from the list of reviewers :fail:")
          end
        end

        ##################
        # List reviewers #
        ##################
        if list_reviewers_request?(message)
          SlackbotFrd::Log.debug(
            "user '#{user}' in channel '#{channel}' is listing reviewers"
          )
          if data.reviewers.any?
            m.send_message("Reviewers are: #{data.users.join(', ')}")
          else
            m.send_message("No reviewers yet! Add one like `codereviewmaster add <name>`")
          end
        end

        ###################
        # Clear reviewers #
        ###################
        if clear_reviewers_request?(message)
          SlackbotFrd::Log.debug(
            "user '#{user}' in channel '#{channel}' is clearing all reviewers"
          )
          if data.reviewers.any? && data.clear_reviewers!
            m.send_message("Reviewers have been cleared!")
          else
            m.send_message("No reviewers yet! Add one like `codereviewmaster add <name>`")
          end
        end

        ####################
        # Output help text #
        ####################
        if help_output_request?(message)
          SlackbotFrd::Log.debug(
            "user '#{user}' in channel '#{channel}' is requesting help output"
          )
          help = <<-HELP_TEXT
Hi! I help assign code reviewers.

*Assign a reviewer*

`codereviewmaster g/123456`

Assigns a code reviewer to the provided gerrit change id. Posts in slack &
assigns a reviewer in gerrit (assuming gerrit is configured).

*List reviewers*

`codereviewmaster list`

Shows list of existing reviewers.

*Add a reviewer*

`codereviewmaster add john`

or

`codereviewmaster add slack:john gerrit:jcorrigan`

Adds a new reviewer. Dups are ignored. If you just provide a string
it assumes the same name for both slack & gerrit. If they are different,
use the second syntax.

*Remove a reviewer*

`codereviewmaster remove jcorrigan`

Works with either username.

*Clear all reviewers*

`codereviewmaster clear`

Removes all reviewers

*Help output*

`codereviewmaster help`

Outputs this text
          HELP_TEXT
          m.send_message(help)
        end

        #####################
        # Assign a reviewer #
        #####################
        if (change_id = assign_review_request?(message))
          SlackbotFrd::Log.debug(
            "user '#{user}' in channel '#{channel}' is requesting a code review " \
            "for change_id: #{change_id}"
          )
          if data.reviewers.any?
            assigned = data.assign_reviewer!(change_id)
            SlackbotFrd::Log.debug(
              "user '#{assigned}' chosen to review '#{change_id}'"
            )
            m.send_message("Hey #{assigned} :wave-1:, can you review this :point_up:")

            unless data.persist_to_gerrit!(
              change_id: change_id,
              assigned: assigned
            )
              m.send_message("Hm, I was unable to add #{assigned} as a reviewer in gerrit.")
            end
          else
            m.send_message("No reviewers yet! Add one like `codereviewmaster add <name>`")
          end
        end
      end
    end
  end

  private

  ######################
  # Determine requests #
  ######################
  def add_reviewer_request?(message)
    (message.downcase.match(/^#{CODEREVIEWMASTER} #{ADD_COMMAND} (.+)/) || [])[1]
  end

  def assign_review_request?(message)
    (message.downcase.match(/^#{CODEREVIEWMASTER} g\/(\d+)/i) || [])[1]
  end

  def clear_reviewers_request?(message)
    message.downcase.match(/^#{CODEREVIEWMASTER} #{CLEAR_COMMAND}$/)
  end

  def codereviewmaster_request?(message)
    message.downcase.match(/^#{CODEREVIEWMASTER}/)
  end

  def help_output_request?(message)
    message.downcase.match(/^#{CODEREVIEWMASTER} #{HELP_COMMAND}$/)
  end

  def list_reviewers_request?(message)
    message.downcase.match(/^#{CODEREVIEWMASTER} #{LIST_COMMAND}$/)
  end

  def remove_reviewer_request?(message)
    (message.downcase.match(/^#{CODEREVIEWMASTER} #{REMOVE_COMMAND} (.+)/) || [])[1]
  end

  def codereviewmaster?(user, message, channel, timestamp, thread_ts)
    message && codereviewmaster_request?(message) && user != :bot && timestamp != thread_ts
  end
end
