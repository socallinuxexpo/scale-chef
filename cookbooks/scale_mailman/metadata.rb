name 'scale_mailman'
maintainer 'Southern California Linux Expo'
maintainer_email 'noreply@socallinuxexpo.org'
license 'All rights reserved'
description 'Installs/Configures scale_apache'
source_url 'https://github.com/socallinuxexpo/scale-chef'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.1.0'

%w{
  scale_apache
  scale_misc
}.each do |cb|
  depends cb
end
