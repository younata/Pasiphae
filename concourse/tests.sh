#!/bin/bash

cd pasiphae
apt-get update -y
apt-get install nodejs -y
bundle install && bundle exec rspec