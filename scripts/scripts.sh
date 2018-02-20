#!/bin/bash

set -e

printf "\n[-] Installing base OS dependencies...\n\n"

apt-get update -y \
&& apt-get install -y --no-install-recommends \
    build-essential \
    bsdtar \
    bzip2 \
    ca-certificates \
    curl \
    git \
    graphicsmagick \
    graphicsmagick-imagemagick-compat \
    python \
    wget \
&& rm -rf /var/lib/apt/lists/*

# Install gosu to build and run the app as a non-root user
# https://github.com/tianon/gosu
dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"
&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
&& export GNUPGHOME="$(mktemp -d)" \
&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
&& chmod +x /usr/local/bin/gosu \
&& gosu nobody true


################################
# install-node
################################
printf "\n[-] Installing Node ${NODE_VERSION}...\n\n" \
&& NODE_DIST=node-v${NODE_VERSION}-linux-x64 \
&& cd /tmp \
&& curl -O -L http://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.gz \
&& tar xvzf ${NODE_DIST}.tar.gz \
&& rm ${NODE_DIST}.tar.gz \
&& rm -rf /opt/nodejs \
&& mv ${NODE_DIST} /opt/nodejs \
&& ln -sf /opt/nodejs/bin/node /usr/local/bin/node \
&& ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm

################################
# install-phantomjs
################################
printf "\n[-] Installing Phantom.js...\n\n"
&& PHANTOM_JS="phantomjs-$PHANTOM_VERSION-linux-x86_64" \
&& apt-get update \
&& apt-get install -y chrpath libssl-dev libxft-dev \
&& cd /tmp \
&& wget https://github.com/Medium/phantomjs/releases/download/v$PHANTOM_VERSION/$PHANTOM_JS.tar.bz2 \
&& tar xvjf $PHANTOM_JS.tar.bz2 \
&& mv $PHANTOM_JS /usr/local/share \
&& ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/share/phantomjs \
&& ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/bin/phantomjs \
&& ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/bin/phantomjs \
&& printf "\n[-] Successfully installed PhantomJS $(phantomjs -v)\n\n"


################################
# install-meteor
# if the Meteor version hasn't been explicitely set, read if from the app
# todo: Consider removing METEOR_VERSION override; Also move this install before copy source files
################################
curl https://install.meteor.com -o /tmp/install_meteor.sh
# set the release version in the install script
&& sed -i.bak "s/RELEASE=.*/RELEASE=\"$METEOR_VERSION\"/g" /tmp/install_meteor.sh \
# replace tar command with bsdtar in the install script (bsdtar -xf "$TARBALL_FILE" -C "$INSTALL_TMPDIR")
# https://github.com/jshimko/meteor-launchpad/issues/39
&& sed -i.bak "s/tar -xzf.*/bsdtar -xf \"\$TARBALL_FILE\" -C \"\$INSTALL_TMPDIR\"/g" /tmp/install_meteor.sh \
&& printf "\n[-] Installing Meteor $METEOR_VERSION...\n\n" \
&& sh /tmp/install_meteor.sh \
&& rm /tmp/install_meteor.sh


################################
# build-meteor
# builds a production meteor bundle directory

# Fix permissions warning in Meteor >=1.4.2.1 without breaking
# earlier versions of Meteor with --unsafe-perm or --allow-superuser
# https://github.com/meteor/meteor/issues/7959
################################
npm i -g reaction-cli \
&& ln -sf /opt/nodejs/bin/reaction /usr/local/bin/reaction

printf "\n[-] Running Reaction plugin loader...\n\n" \
&& reaction plugins load

# Install app deps
# todo: review if this can be cached as a RUN step
printf "\n[-] Running npm install in app directory...\n\n" \
&& meteor npm install

# build the bundle
printf "\n[-] Building Meteor application...\n\n" \
&& mkdir -p $APP_BUNDLE_DIR \
&& meteor build --allow-superuser --directory $APP_BUNDLE_DIR

# run npm install in bundle
printf "\n[-] Running npm install in the server bundle...\n\n" \
&& cd $APP_BUNDLE_DIR/bundle/programs/server/ \
&& meteor npm install --production

# put the entrypoint script in WORKDIR
# todo: Consider using COPY command in the dockerfile
mv $BUILD_SCRIPTS_DIR/entrypoint.sh $APP_BUNDLE_DIR/bundle/entrypoint.sh

# change ownership of the app to the node user
chown -R node:node $APP_BUNDLE_DIR
