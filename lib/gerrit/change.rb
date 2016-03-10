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
      ret = self.class.get("/#{id}/detail", digest_auth: digest_auth).body.split("\n")
      # gerrit puts some weird cruft in the way at the top
      ret.shift
      JSON.parse(ret.join("\n"))
    end

    private

    def digest_auth
      {
        username: @username,
        password: @password
      }
    end
  end
end
