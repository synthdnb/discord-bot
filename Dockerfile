FROM ruby:2.5.0-alpine
RUN gem update --system && gem install bundler -v 1.16.1
RUN apk update && apk add build-base

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle install

COPY bot.rb /usr/src/app

CMD ["./bot.rb"]