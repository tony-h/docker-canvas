FROM ubuntu:14.04
# https://github.com/instructure/canvas-lms/wiki/Production-Start

RUN apt-get -y update && \
    apt-get -y install curl apt-transport-https ca-certificates && \
    (apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7) && \
    (echo deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main > /etc/apt/sources.list.d/passenger.list) && \
    apt-get -y update && \
    apt-get -y install software-properties-common python-software-properties \
    zlib1g-dev libxml2-dev libmysqlclient-dev libxslt1-dev \
    imagemagick libpq-dev libxmlsec1-dev libcurl4-gnutls-dev \
    libxmlsec1 build-essential openjdk-7-jre unzip git-core \
    libapache2-mod-passenger apache2 python-lxml libsqlite3-dev \
    passenger passenger-dev nodejs ruby-multi-json make g++
RUN apt-add-repository -y ppa:brightbox/ruby-ng
RUN apt-get -y update && apt-get -y install ruby2.2 ruby2.2-dev 
RUN curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
RUN apt-get install nodejs

RUN cd /opt && git clone --depth 1 --branch stable https://github.com/instructure/canvas-lms.git
RUN gem install bundler --version 1.12.5
RUN cd /opt/canvas-lms && bundle install --path vendor/bundle --without=sqlite
ADD amazon_s3.yml /opt/canvas-lms/config/
ADD database.yml /opt/canvas-lms/config/
ADD delayed_jobs.yml /opt/canvas-lms/config/
ADD domain.yml /opt/canvas-lms/config/
ADD file_store.yml /opt/canvas-lms/config/
ADD outgoing_mail.yml /opt/canvas-lms/config/
ADD security.yml /opt/canvas-lms/config/
ADD external_migration.yml /opt/canvas-lms/config/
ADD saml.yml /opt/canvas-lms/config/
ADD cache_store.yml /opt/canvas-lms/config/
ADD redis.yml /opt/canvas-lms/config/
ADD selenium.yml /opt/canvas-lms/config/
WORKDIR /opt/canvas-lms
RUN adduser --disabled-password --gecos canvas canvasuser
RUN mkdir -p log tmp/pids public/assets public/stylesheets/compiled
RUN touch Gemfile.lock
RUN chown -R canvasuser config/environment.rb log tmp app public Gemfile.lock config.ru
# https://github.com/instructure/canvas-lms/wiki/Production-Start#apache-configuration
ENV RAILS_ENV production
# ruby barfs at non-ascii, need to set encoding.
RUN npm install --unsafe-perm
RUN find /opt/canvas-lms/vendor/bundle/ruby \
         -name extractor.rb \
         -exec sed -i -e 's/File.read(path)/File.read(path, :encoding => "UTF-8")/' {} \; && \
    bundle exec rake canvas:compile_assets
RUN a2enmod passenger && a2enmod ssl && a2enmod rewrite
ADD canvas_apache.conf /etc/apache2/sites-available/canvas.conf
ADD apache2-wrapper.sh /root/apache2
RUN a2dissite 000-default
RUN a2ensite canvas
RUN cd /opt/canvas-lms/vendor && git clone https://github.com/instructure/QTIMigrationTool.git QTIMigrationTool
RUN chmod +x /opt/canvas-lms/vendor/QTIMigrationTool/migrate.py

EXPOSE 80
EXPOSE 443

CMD ["/bin/bash","/root/apache2"]
