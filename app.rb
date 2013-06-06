require 'sinatra'
require 'data_mapper'
require 'faraday'
# require 'twiliolib'
require 'twilio-ruby'
require 'pony'

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/uptime')

MY_CELL_PHONE = ENV["MY_CELL_PHONE"]
MY_EMAIL_ADDRESS = ENV["MY_EMAIL_ADDRESS"]
MY_TWILIO_NUM = ENV["MY_TWILIO_NUM"]
TWILIO_API_VERSION = "2010-04-01"
TWILIO_ACCOUNT_SID = ENV["TWILIO_ACCOUNT_SID"]
TWILIO_ACCOUNT_TOKEN = ENV["TWILIO_ACCOUNT_TOKEN"]

class Site
  include DataMapper::Resource

  property :id, Serial
  property :url, String
  property :last_check, DateTime
  property :status_changed, DateTime
  property :current_status, String, :default => "up"
  property :notify, Boolean, :default => true

  validates_uniqueness_of :url
  def down?
    current_status == 'down'
  end
end

class NotificationManager

  def self.notify(message)
    NotificationManager.send_text message
    NotificationManager.send_email message
  end
  
  def self.send_text(message)
    # Create a Twilio REST client object using your Twilio account ID and token
    client = Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_ACCOUNT_TOKEN)

    # Send the request and get a response
    begin
      client.account.sms.messages.create({
        :from => MY_TWILIO_NUM,
        :to => MY_CELL_PHONE,
        :body => message
      })
    rescue Exception => e
      puts "Could not send SMS via Twilio"
      return
    end

    # Handle success case...
  end

  def self.send_email(message)
    return false if MY_EMAIL_ADDRESS.nil?
    
    if !ENV['SENDGRID_USERNAME'].nil?
      Pony.options = {
        :from => "#{MY_EMAIL_ADDRESS} <#{MY_EMAIL_ADDRESS}>",
        :to => MY_EMAIL_ADDRESS,
        :subject => "Uptime Notification",
        :body => message,
        :via => :smtp,
        :via_options => {
          :address => 'smtp.sendgrid.net',
          :port => '587',
          :domain => ENV['SENDGRID_DOMAIN'],
          :user_name => ENV['SENDGRID_USERNAME'],
          :password => ENV['SENDGRID_PASSWORD'],
          :authentication => :plain,
          :enable_starttls_auto => true
        }
      }
    elsif !ENV['MANDRILL_USERNAME'].nil?
      Pony.options = {
        :from => "#{MY_EMAIL_ADDRESS} <#{MY_EMAIL_ADDRESS}>",
        :to => MY_EMAIL_ADDRESS,
        :subject => "Uptime Notification",
        :body => message,
        :via => :smtp,
        :via_options => {
          :address => 'smtp.mandrillapp.com',
          :port => '587',
          :user_name => ENV['MANDRILL_USERNAME'],
          :password => ENV['MANDRILL_APIKEY'],
          :authentication => :login,
          :enable_starttls_auto => true
        }
      }
    else
      return false
    end
      
  end

end

# DataMapper.finalize.auto_upgrade!
DataMapper.auto_upgrade!
# Delayed::Worker.backend.auto_upgrade!

get '/' do
  erb :index
end

###################
# METHODS
###################
def check_site(site)
  site.last_check = Time.now

  status = result = nil
  (1..3).each do |x|
    begin
      result = get_url(site.url)
      status = is_down?(result) ? 'down' : 'up'

    rescue Faraday::Error::ConnectionFailed
      puts "That is not a real site"
      status = "down"
    end

    break if status == 'up'
    sleep(1)
  end

  if site.current_status != status
    site.current_status = status
    site.status_changed = site.last_check
    notify_change(site) if site.notify
  end
  raise "couldn't save" if !site.save
end

def get_url(uri)
  conn = Faraday.new(:url => uri) do |faraday|
    faraday.request  :url_encoded             # form-encode POST params
    faraday.response :logger                  # log requests to STDOUT
    faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
  end

  response = conn.get
  response.status
  # response.response.kind_of?(Net::HTTPSuccess)
end

def is_down?(result)
  return false if result.to_i >= 200 && result.to_i < 400  #result.kind_of?(Net::HTTPSuccess) || result.kind_of?(Net::HTTPRedirection)
  true
end

def notify_change(site)
  NotificationManager.notify "#{site.url} is #{site.current_status}"
end
