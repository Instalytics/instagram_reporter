require 'rubygems'

require 'faraday'
require 'faraday_middleware'
require 'json'
require 'capybara'
require 'capybara/dsl'
require 'csv'
require 'nokogiri'
require 'open-uri'
require 'mongoid'
require 'mongoid_to_csv'

module NokoParser
  class Main

    def contact_data_email(data)
      if data.match(/([^@\s*]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})/i) != nil ? true : false
        return data.match(/([^@\s*]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})/i).to_s
      end
    end

    def contact_data(data)
      # checking for email
      if data.match(/([^@\s*]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})/i) != nil ? true : false
        return data.gsub(',', '')
      end

      %w(contact business Business Facebook facebook fb email Twitter twitter Contact FB tumblr Blog blog mail http www).each do |ci|
        return data.gsub(',', '') if data.include?(ci)
      end
      return nil
    end

    def get_followers_number(follower_name)
      returnee = nil
      conn = Faraday.new(:url => "https://instagram.com" ) do |faraday|
        faraday.use FaradayMiddleware::FollowRedirects
        faraday.adapter :net_http
      end

      response = conn.get "/#{follower_name}"

      doc = Nokogiri::HTML(response.body)
      doc.css('script').each do |k|
        begin
          JSON.parse(k.content.match(/\[{"componentName".*}\]/).to_s).each do |el|
            returnee = el['props']['user']
          end
        rescue
        end
      end

      i = InstagramUser.create({ 
        username:          returnee['username'],
        email:             contact_data_email(returnee['bio']),
        followers:         returnee['counts']['followed_by'].to_i / 1000,
        bio:               contact_data(returnee['bio']),
        created_at:        DateTime.now,
        updated_at:        DateTime.now,
        already_presented: false
      })
      print "." if i.valid?
    end
  end
end

module InstagramerGetter
  class Main < InstagramInteractionsBase

    FOLLOWERS_LIMIT = 10

    def initialize
      puts "Starting InstagramerGetter!"
      @mongoid_config = Rails.root.join("config", "mongoid.yml").to_s
      get_old_users_from_csv

      conn = Faraday.new(:url => API_BASE_URL ) do |faraday|
        faraday.request  :url_encoded
        faraday.adapter  Faraday.default_adapter
      end

      response = conn.get do |req|
        req.url "/v1/media/popular?client_id=#{TOKENS.shuffle.first}"
        req.options = { timeout: 15, open_timeout: 15}
      end

      data = JSON.parse(response.body)['data']

      puts
      puts 'getting new users from instagram'
      puts
      data.each do |u|
        usr_name = u['user']['username']
        NokoParser::Main.new.get_followers_number(usr_name)
      end
    end

    def get_old_users_from_csv
      puts "checking oldusers.csv"
      old_users_csv_file = Rails.root.join("lib", 'oldusers.csv').to_s
      CSV.foreach(old_users_csv_file) do |csv|
        print "."
        if csv[1] != nil || csv[1] != ""
          i = InstagramUser.create({
            username: csv[1],
            email: '',
            followers:'',
            bio: '',
            created_at: DateTime.now.advance(days:-30),
            updated_at: DateTime.now.advance(days:-30)
          })
          puts "Created new user from olduser.csv: #{csv[1]}" if i.valid?
        end
      end
    end
  end
end
