#!/bin/bash

#[参考記事]
#丁寧すぎるDocker-composeによるrails + MySQL on Dockerの環境構築(Docker for Mac)
#https://qiita.com/azul915/items/5b7063cbc80192343fc0

#config setting#############
MYSQL_PASSWORD="hogehoge"
###########################

echo "** docker pull ruby2.7.2"
docker pull ruby:2.7.2

echo "** docker pull mysql:5.7"
docker pull mysql:5.7

echo "** docker images"
docker images

echo "** make Dockerfile"
cat <<'EOF' > Dockerfile
FROM ruby:2.7.2

ENV LANG C.UTF-8
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs vim

#yarnのセットアップ
RUN curl -o- -L https://yarnpkg.com/install.sh | bash
ENV PATH /root/.yarn/bin:/root/.config/yarn/global/node_modules/.bin:$PATH

# 作業ディレクトリの作成、設定
RUN mkdir /app_sv 
ENV APP_ROOT /app_sv
WORKDIR $APP_ROOT

# # ホスト側（ローカル）のGemfileを追加する
ADD ./Gemfile $APP_ROOT/Gemfile
ADD ./Gemfile.lock $APP_ROOT/Gemfile.lock

# # Gemfileのbundle install 
RUN bundle install

ADD . $APP_ROOT

# #webpackerの設定
# RUN rails webpacker:install
EOF

echo "** make Gemfile"
# touch Gemfile
cat <<EOF > Gemfile
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'rails', '~> 6.0.1'
EOF

echo "** make Gemfile.lock"
touch Gemfile.lock

echo "** make docker-compose.yml"
cat <<EOF > docker-compose.yml
version: '3'
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: root
    ports:
      - '3306:3306'
    logging:
      driver: "json-file" # defaults if not specified
      options:
        max-size: "10m"
        max-file: "3"

  web:
    build: .
    command: bundle exec rails s -p 3000 -b '0.0.0.0'
    volumes:
      - .:/app_sv
    ports:
      - '3000:3000'
    links:
      - db
    stdin_open: true
    tty: true
    logging:
      driver: "json-file" # defaults if not specified
      options:
        max-size: "10m"
        max-file: "3"
EOF

echo "** docker-compose run web rails new . --force --database=mysql"
docker-compose run web rails new . --force --database=mysql

echo "** docker-compose build "
docker-compose build

echo "** docker-compose run web bundle exe rails webpacker:install "
docker-compose run web rails webpacker:install

# fix config/database.yml
echo "** fix config/database.yml"
cat config/database.yml | sed "s/password:$/password: ${MYSQL_PASSWORD}/" | sed "s/host: localhost/host: db/" > __tmpfile__
cat __tmpfile__ > config/database.yml
rm __tmpfile__

echo "** docker-compose run web bundle rails db:create"
docker-compose run web rails db:create

echo "** docker-compose up"
docker-compose up
