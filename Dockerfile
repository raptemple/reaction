FROM node:8.9
MAINTAINER Reaction Commerce <admin@reactioncommerce.com>

# Define all --build-arg options
ARG INSTALL_PHANTOMJS
ARG TOOL_NODE_FLAGS=--max-old-space-size=2048
ARG METEOR_VERSION=1.6.0.1

ENV ROOT_URL http://localhost
ENV PORT 3000
ENV GOSU_VERSION 1.10
ENV PHANTOM_VERSION 2.1.1
ENV REACTION_DOCKER_BUILD true
ENV APP_SOURCE_DIR /opt/reaction/src
ENV APP_BUNDLE_DIR /opt/reaction/dist
ENV BUILD_SCRIPTS_DIR /opt/build_scripts
ENV METEOR_ALLOW_SUPERUSER=true
ENV METEOR_VERSION $METEOR_VERSION
ENV PHANTOM_JS=phantomjs-$PHANTOM_VERSION-linux-x86_64

ENV INSTALL_PHANTOMJS $INSTALL_PHANTOMJS
ENV TOOL_NODE_FLAGS $TOOL_NODE_FLAGS

# Add entrypoint and build scripts
COPY scripts $BUILD_SCRIPTS_DIR
RUN chmod -R 750 $BUILD_SCRIPTS_DIR

RUN apt-get update -y \
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
RUN dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
 && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
 && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
 && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true

# install-phantomjs
RUN printf "\n[-] Installing Phantom.js...\n\n" \
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
# replaces tar command with bsdtar in the install script (bsdtar -xf "$TARBALL_FILE" -C "$INSTALL_TMPDIR")
# https://github.com/jshimko/meteor-launchpad/issues/39
################################
RUN curl https://install.meteor.com -o /tmp/install_meteor.sh \
 && sed -i.bak "s/RELEASE=.*/RELEASE=\"$METEOR_VERSION\"/g" /tmp/install_meteor.sh \
 && sed -i.bak "s/tar -xzf.*/bsdtar -xf \"\$TARBALL_FILE\" -C \"\$INSTALL_TMPDIR\"/g" /tmp/install_meteor.sh \
 && printf "\n[-] Installing Meteor $METEOR_VERSION...\n\n" \
 && sh /tmp/install_meteor.sh \
 && rm /tmp/install_meteor.sh

RUN npm i -g reaction-cli

COPY . $APP_SOURCE_DIR
WORKDIR $APP_SOURCE_DIR

RUN printf "\n[-] Running Reaction plugin loader...\n\n" \
 && reaction plugins load

# Install app deps
RUN printf "\n[-] Running npm install in app directory...\n\n" \
 && meteor npm install

# build production bundle
RUN printf "\n[-] Building Meteor application...\n\n" \
 && mkdir -p $APP_BUNDLE_DIR \
 && meteor build --allow-superuser --directory $APP_BUNDLE_DIR

# run npm install in bundle
RUN printf "\n[-] Running npm install in the server bundle...\n\n" \
 && cd $APP_BUNDLE_DIR/bundle/programs/server/ \
 && meteor npm install --production

# put the entrypoint script in WORKDIR
# todo: Consider using COPY command in the dockerfile
COPY scripts/entrypoint.sh $APP_BUNDLE_DIR/bundle/entrypoint.sh

# change ownership of the app to the node user
RUN chown -R node:node $APP_BUNDLE_DIR

EXPOSE 3000

WORKDIR $APP_BUNDLE_DIR/bundle

# start the app
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "main.js"]
