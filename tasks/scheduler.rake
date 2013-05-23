desc "Check sites to see if they are up or down"
task :check_sites => :environment do
  puts "Start checking sites"
  
  Site.all.each do |site|
    check_site(site)
  end

  puts "Done"
end