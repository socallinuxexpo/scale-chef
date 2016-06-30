name             'scale_phplist'
maintainer       'scale'
maintainer_email 'tech@lists.linuxfests.org'
license          'All rights reserved'
description      'Installs/Configures scale_apache'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

%w{
  tarball
}.each do |cb|
  depends cb
end
