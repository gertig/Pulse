require 'rubygems'
require 'rake'
require 'rake/clean'
# require 'rubygems/package_task'
# require 'rake/task'
# require 'rake/testtask'

# Dir["#{File.dirname(__FILE__)}/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["tasks/*.rake"].sort.each { |ext| load ext }

task :environment do
  require './app.rb'
end