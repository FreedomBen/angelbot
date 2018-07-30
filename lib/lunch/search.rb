
require 'httparty'
require 'json'

module Lunch
    class Search
        include HTTParty
        base_uri "https://api.yelp.com/"
        headers 'Authorization' => 'Bearer FMgmMCHUrSSLBuetlQnI0TEFlOFoRV94TEEwkRafuoaZXac7WmocnNPBZDZOtyEF1Og8f2sYdapl_QfBD7DDxKDGCz4iSWf2QW-tGgnCBNea5We8Sw94JJhluoo6W3Yx'

        def get(distance, cost)
            uri  = self.class.get("/v3/businesses/search", query: "term=restaurant&location=6330+S+3000+E+Salt+Lake+City+UT+84121&price=#{cost}&radius=#{distance.to_i*1609}&limit=50").body
            JSON.parse(uri)
        rescue 
            { total: 0 }
        end
    end
end