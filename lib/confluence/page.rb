require 'httparty'
require 'json'

require_relative 'base'

module Confluence
  class Page
    include HTTParty
    base_uri "#{Confluence.base_url}/content"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(id)
      JSON.parse(self.class.get("/#{id}?expand=body.storage,version", basic_auth: basic_auth, timeout: 5).body)
    rescue JSON::ParserError => e
      { error: 'Confluence returned invalid JSON (probably an error page in HTML :facepalm: )' }
    rescue StandardError => e
      { error: 'Unknown error occurred when querying Confluence' }
    end

    def update(id, title:, content:, version:)
      body = update_hash(
        title: title,
        content: content,
        version: version
      ).to_json

      JSON.parse(self.class.put("/#{id}", body: body,
                                          basic_auth: basic_auth,
                                          headers: {
                                            'Content-Type' => 'application/json'
                                          },
                                          timeout: 5).body)
    end

    def prepend_content(page_id:, user:, channel:, channel_id:, timestamp:, content:)
      @user = user
      @channel = channel
      @channel_id = channel_id
      @timestamp = timestamp
      @page = get page_id

      update(
        page_id,
        title: @page['title'],
        content: prepended_html(content),
        version: @page['version']['number'] + 1
      )
    end

    private

    def basic_auth
      {
        username: @username,
        password: @password
      }
    end

    def update_hash(title:, content:, version:)
      {
        body: {
          storage: {
            value: content.to_s,
            representation: 'storage'
          }
        },
        version: {
          number: version
        },
        type: 'page',
        title: title.to_s
      }
    end

    def slack_url(channel_id, timestamp)
      "https://instructure.slack.com/archives/#{channel_id}/p#{timestamp.to_s.delete('.')}"
    end

    def prepended_html(content)
      "
        <p>
          <span style='font-size: 12.0px;font-weight: bold;'>Posted by #{@user} in ##{@channel} on <a href='#{slack_url(@channel_id, @timestamp)}'>#{Time.at(@timestamp).utc}</a></span>
        </p>
        <blockquote>
          <p>#{content}</p>
        </blockquote>
        <br /><br />
        #{@page['body']['storage']['value']}
      "
    end
  end
end
