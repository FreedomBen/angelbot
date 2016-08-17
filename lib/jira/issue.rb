require 'httparty'
require 'json'

require_relative 'base'
require_relative 'user'

module Jira
  class Issue
    include HTTParty
    base_uri "#{Jira.base_url}/issue"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(id)
      JSON.parse(self.class.get("/#{id}", basic_auth: basic_auth).body)
    end

    def create(project:, issue_type:, summary:, description:)
      JSON.parse(self.class.post('/', {
        body: creation_hash(
          project: project,
          issue_type: issue_type,
          summary: summary,
          description: description
        ).to_json,
        basic_auth: basic_auth,
        headers: {
          'Content-Type' => 'application/json'
        }
      }).body)
    end

    def set_reporter(issue_id, reporter)
    end

    private

    def basic_auth
      {
        username: @username,
        password: @password
      }
    end

    def creation_hash(project:, issue_type:, summary:, description:, reporter_name: nil)
      retval = {
        fields: {
          project: {
            key: project
          },
          summary: summary,
          description: description,
          issuetype: {
            name: issue_type
          }
        }
      }
      if reporter_name
        retval[:fields][:reporter] = {}
        retval[:fields][:reporter][:name] = reporter_name
      end
      retval
    end
  end
end
