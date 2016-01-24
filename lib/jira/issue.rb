require 'httparty'
require 'json'

require_relative 'base'

module Jira
  class Issue
    include HTTParty
    base_uri "#{Jira.base_url}/issue"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(id)
      JSON.parse(self.class.get("/#{id}", basic_auth: {username: @username, password: @password}).body)
    end
  end
end
