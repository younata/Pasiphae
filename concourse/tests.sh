#!/bin/bash

cd pasiphae_github
apt-get update -y
apt-get install nodejs -y
bundle install && bundle exec rspec