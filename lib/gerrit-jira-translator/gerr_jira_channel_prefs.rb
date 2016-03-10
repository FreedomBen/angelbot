class GerritJiraChannelPrefs
  attr_accessor :jira_expansion

  def self.from_hash(hash)
    n = GerritJiraChannelPrefs.new
    if hash
      n.jira_expansion = hash[:jira_expansion] ||
        hash['jira_expansion'] ||
        default_jira_verbosity
    end
    n
  end

  def self.from_json(json)
    if json
      from_hash(JSON.parse(json))
    else
      self.new
    end
  end

  def self.default_jira_verbosity
    'full_ticket'
  end

  def initialize(jira_expansion: GerritJiraChannelPrefs.default_jira_verbosity)
    valid_jira_verbosity?(jira_expansion)
    @jira_expansion = jira_expansion
  end

  def to_json
    to_hash.to_json
  end

  def to_hash
    retval = {}
    retval[:jira_expansion] = jira_expansion
    retval
  end

  def jira_verbosity_settings
    %w[
      full_ticket
      link_only
      off
    ]
  end

  def valid_jira_verbosity?(verbosity)
     jira_verbosity_settings.include?(verbosity)
  end

  def changes?(key, val)
    if valid_keys.include?(key)
      send(key) != val
    else
      raise ArgumentError.new("Invalid key '#{key}'")
    end
  end

  def set(key, val)
    if valid_keys.include?(key)
      send("#{key}=", val)
    else
      raise ArgumentError.new("Invalid key '#{key}'")
    end
  end

  def equals?(other)
    self.jira_expansion == other.jira_expansion
  end

  private

  def valid_keys
    # These are valid settings for which we can call send()
    %w[
      jira_expansion
    ]
  end

  def validate_jira_verbosity(verbosity)
    raise ArgumentError.new(
      "Verbosity must be one of '#{jira_verbosity_settings.join(', ')}'"
    ) unless valid_jira_verbosity?(verbosity)
  end
end
