FROM debian:jessie
MAINTAINER Reaction Commerce <admin@reactioncommerce.com>

RUN groupadd -r node && useradd -m -g node node

# Define all --build-arg options
ARG NODE_VERSION=8.9.0
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

ENV NODE_VERSION $NODE_VERSION
ENV INSTALL_PHANTOMJS $INSTALL_PHANTOMJS
ENV TOOL_NODE_FLAGS $TOOL_NODE_FLAGS

# Add entrypoint and build scripts
COPY scripts $BUILD_SCRIPTS_DIR
RUN chmod -R 750 $BUILD_SCRIPTS_DIR

COPY . $APP_SOURCE_DIR
WORKDIR $APP_SOURCE_DIR

# run install, build, and cleanup commands
# todo: include scripts directly in dockerfile
RUN $BUILD_SCRIPTS_DIR/scripts.sh


EXPOSE 3000

WORKDIR $APP_BUNDLE_DIR/bundle



# start the app
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "main.js"]
