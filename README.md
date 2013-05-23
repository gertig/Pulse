## Development

Start application with:

    $ bundle
    $ createdb yourappname
    $ shotgun app.rb
    
Or if using Foreman, .env, and a Procfile
    
    $ foreman start

To access and change data via the console

    $ irb
    $ require './app.rb'
    
Create your first Site

    $ Site.create(url: "http://andrewgertig.com")
    
Open your browser to whichever PORT you are using, (for me I have it set to PORT=5002 in my .env file) and you should see something like this:

![Heroku Scheduler](assets/site-demo.png)

Green means the site is up, Red means its down. I used to own two.io but couldn't ever figure out what to do with it :disappointed:
    
## Twilio Setup

1. Get a Twilio SMS account and add your phone number and keys to your .env file
2. Add your Twilio keys to Heroku config

````
$ heroku config:add MY_TWILIO_NUM=5558675309 TWILIO_ACCOUNT_SID=XXXXXXXXXSIDXXXXXXXX TWILIO_ACCOUNT_TOKEN=XXXXXXXXTOKENXXXXXXXX
````
    
## Heroku Scheduler

In order to check to see if a site is "UP" or "DOWN" you will need to setup a scheduled rake task using Heroku's Scheduler

    $ heroku addons:add scheduler:standard
    $ heroku addons:open scheduler
    
Create a Job that runs "rake check\_sites" every 10 minutes, it should look like this once you are done: 

![Heroku Scheduler](assets/heroku-scheduler.png)  
  
## Datamapper Basics

**Create**

    $ Site.create(url: "http://andrewgertig.com")

**Find**

    $ Site.get(1)
    $ Site.first(:url => "http://andrewgertig.com")

**Destroy**

    $ site = Site.get(5)
    $ site.destroy  # => true

####[Datamapper Documentation](http://datamapper.org/docs/)