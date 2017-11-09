module CodeReviewMaster
  class User
    def initialize(attrs)
      @attrs = attrs
    end

    def gerrit_username
      attrs['gerrit']
    end

    def slack_username
      attrs['slack']
    end

    def to_h
      attrs
    end

    def to_s
      slack_username
    end

    private
    attr_reader :attrs
  end
end
