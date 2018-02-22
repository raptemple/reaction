FROM node:8.9
MAINTAINER Reaction Commerce <admin@reactioncommerce.com>

# Define all --build-arg options
ARG INSTALL_PHANTOMJS
ARG TOOL_NODE_FLAGS=--max-old-space-size=2048
ARG METEOR_VERSION=1.6.0.1

ENV ROOT_URL http://localhost
ENV PORT 3000
ENV REACTION_DOCKER_BUILD true
ENV APP_SOURCE_DIR /opt/reaction/src
ENV APP_BUNDLE_DIR /opt/reaction/dist
ENV BUILD_SCRIPTS_DIR /opt/build_scripts
ENV METEOR_ALLOW_SUPERUSER=true
ENV METEOR_VERSION $METEOR_VERSION
ENV TOOL_NODE_FLAGS $TOOL_NODE_FLAGS

RUN apt-get update -y \
 && apt-get install -y --no-install-recommends \
      build-essential \
      bsdtar \
      bzip2 \
      ca-certificates \
      curl \
      python \
 && rm -rf /var/lib/apt/lists/*

WORKDIR $APP_SOURCE_DIR

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

COPY package.json $APP_SOURCE_DIR

RUN meteor npm install

COPY . $APP_SOURCE_DIR

RUN reaction plugins load

EXPOSE 3000

CMD ["node", "main.js"]
