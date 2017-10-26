module CodeReviewMaster
  # Translates a string into a hash understood by the
  # User object
  #
  # Either a single string name like:
  #
  # `jcorrigan`
  #
  # or one or more key value pairs
  #
  # `slack:john gerrit:jcorrigan`
  #
  # If you only provide one (for some reason) it
  # sets it for all keys, in this case, slack & gerrit.
  class MessageSegment
    class ParseError < StandardError; end

    KEYS = [
      'slack', 'gerrit'
    ]

    def initialize(message_segment)
      @message_segment = message_segment
    end

    def to_user
      a = message_segment.split(' ')

      if a.length == 1
        User.new({
          'slack' => a.first,
          'gerrit' => a.first
        })
      else
        h = pad_empty_keys(assign_usernames(a))
        User.new(h)
      end
    end

    private
    attr_reader :message_segment

    def assign_usernames(segments)
      segments.each_with_object({}) do |s, memo|
        k, v = s.split(':')
        raise ParseError unless k && v

        if KEYS.include?(k)
          memo[k] = v
        end
      end
    end

    def pad_empty_keys(h)
      KEYS.each do |k|
        h[k] = a[0].split(':')[1] unless h.keys.include?(k)
      end
      h
    end
  end
end
