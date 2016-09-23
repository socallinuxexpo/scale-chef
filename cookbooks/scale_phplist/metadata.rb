name 'scale_phplist'
maintainer 'Southern California Linux Expo'
maintainer_email 'noreply@socallinuxexpo.org'
license 'All rights reserved'
description 'Installs/Configures scale_apache'
source_url 'https://github.com/socallinuxexpo/scale-chef'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.1.0'

%w{
  fb_apache
  scale_apache
}.each do |cb|
  depends cb
end
