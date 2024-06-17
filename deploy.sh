#!/bin/bash

echo "DEPLOYING CLIPPY"

TAG=$1

gem build skipper_client.gemspec
mkdir -p ~/.gem
echo -e "---\r\n:rubygems_api_key: $RUBY_GEM_API_KEY" > ~/.gem/credentials
chmod 0600 ~/.gem/credentials
gem push skipper-cli-*.gem
