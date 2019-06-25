FROM ruby:2.5.3

LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

# required for envsubst tool
RUN ( \
   apt-get update ; \
   apt-get install -y --no-install-recommends  gettext-base ; \
   rm -rf /var/lib/apt/lists/* ; \
   groupadd -r travis && useradd -m -r -g travis travis ; \
   mkdir -p /usr/src/app ; \
   chown -R travis:travis /usr/src/app \
)

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

USER travis
WORKDIR /usr/src/app

COPY Gemfile      /usr/src/app
COPY Gemfile.lock /usr/src/app

RUN bundle install

COPY . /usr/src/app

CMD bundle exec je sidekiq -c 25 -r ./lib/travis/tasks.rb -q notifications -q campfire -q email -q flowdock -q github_commit_status -q github_status -q hipchat -q irc -q webhook -q slack -q pushover
