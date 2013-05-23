Start application with:
$ bundle
$ createdb yourappname
$ shotgun app.rb

To access and change data via the console

$ irb
$ require './app.rb'
$ Site.all.first

### Create
$ Site.create(url: "http://laternote.com")

### Find
$ Site.get(1)
$ Site.first(:url => "http://laternote.com")

### Destroy

$ site = Site.get(5)
$ site.destroy  # => true

### Datamapper Documentation
[Datamapper](http://datamapper.org/docs/)