require 'httparty'
require 'json'

require_relative 'base'

module Gerrit
  class Change
    include HTTParty
    base_uri "#{Gerrit.base_url}/changes"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(id)
      ret = self.class.get("/#{id}/detail", basic_auth: basic_auth)
      # gerrit puts some weird cruft in the way at the top
      return "Error: #{ret.code}" if ret.code != 200
      ret = ret.body.split("\n")
      ret.shift
      JSON.parse(ret.join("\n"))
    end

    private

    def basic_auth
      {
        username: @username,
        password: @password
      }
    end
  end
end
