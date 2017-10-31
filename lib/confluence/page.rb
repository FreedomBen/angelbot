require 'httparty'
require 'json'

require_relative 'base'

module Confluence
  class Page
    include HTTParty
    base_uri "#{Confluence.base_url}/content"
    class ConfluenceError < StandardError; end

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

      resp = self.class.put("/#{id}", body: body,
                                      basic_auth: basic_auth,
                                      headers: {
                                        'Content-Type' => 'application/json'
                                      },
                                      timeout: 5).body

      SlackbotFrd::Log.info('Got response from Confluence when updating a page:')
      SlackbotFrd::Log.info(resp)
      JSON.parse(resp)
    end

    def prepend_content(page_id:, author:, created_at:, channel:, channel_id:, ts:, content:)
      @author = author
      @created_at = created_at
      @channel = channel
      @channel_id = channel_id
      @ts = ts
      @page = get(page_id)
      @content = prepended_html(content)

      SlackbotFrd::Log.info('Prepending Confluence page using the data:')
      SlackbotFrd::Log.info("
        @author: #{@author}
        @created_at: #{@created_at}
        @channel: #{@channel}
        @channel_id: #{@channel_id}
        @ts: #{@ts}
        @page: #{@page}
        @content: #{@content}
      ")

      resp = update(
        page_id,
        title: @page['title'],
        content: @content,
        version: @page['version']['number'] + 1
      )

      raise(ConfluenceError, resp['message']) unless resp['data']['successful']
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
            value: content,
            representation: 'storage'
          }
        },
        version: {
          number: version
        },
        type: 'page',
        title: title
      }
    end

    def slack_url(channel_id, timestamp)
      "https://instructure.slack.com/archives/#{channel_id}/p#{timestamp.to_s.delete('.')}"
    end

    def prepended_html(content)
      new_psa = "
        <p>
          <span style='font-size: 12.0px;font-weight: bold;'>Posted by #{@author} in ##{@channel} on <a href='#{slack_url(@channel_id, @ts)}'>#{@created_at}</a></span>
        </p>
        <blockquote>
          <p>#{content}</p>
        </blockquote>
        <br /><br />
      "
      @page['body']['storage']['value'].prepend(new_psa)
    end
  end
end
