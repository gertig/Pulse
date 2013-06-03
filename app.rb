require 'sinatra'
require 'data_mapper'
require 'faraday'
require 'twiliolib'

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
    return false if MY_TWILIO_NUM.nil?

    d = {
        'From' => MY_TWILIO_NUM,
        'To' => MY_CELL_PHONE,
        'Body' =>  message
    }

    begin
        account = Twilio::RestAccount.new(TWILIO_ACCOUNT_SID, TWILIO_ACCOUNT_TOKEN)
        resp = account.request(
            "/#{TWILIO_API_VERSION}/Accounts/#{TWILIO_ACCOUNT_SID}/SMS/Messages",
            'POST', d)
        resp.error! unless resp.kind_of? Net::HTTPSuccess
    rescue StandardError => bang
        redirect_to({ :action => '.', 'msg' => "Error #{ bang }" })
        return
    end
  end

  def self.send_email(message)
    return false if ENV['SENDGRID_USERNAME'].nil? || MY_EMAIL_ADDRESS.nil?

    Pony.options = {
      :from => "#{MY_EMAIL_ADDRESS}<#{MY_EMAIL_ADDRESS}>",
      :to => MY_EMAIL_ADDRESS,
      :subject => "Uptime Notification",
      :body => message,
      :via => :smtp,
      :via_options => {
        :address => 'smtp.sendgrid.net',
        :port => '587',
        :domain => 'heroku.com',
        :user_name => ENV['SENDGRID_USERNAME'],
        :password => ENV['SENDGRID_PASSWORD'],
        :authentication => :plain,
        :enable_starttls_auto => true
      }
    }
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

  response = conn.get #'/nigiri/sake.json'
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
