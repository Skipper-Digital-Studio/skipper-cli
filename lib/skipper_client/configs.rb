# frozen_string_literal: true

require 'json'

class Config
  @@configs_path = './config.json'

  attr_reader :uri, :token

  def initialize
    data = read_configs
    @uri = data['uri']
    @token = data['token']
  end

  private

  def read_configs
    file = File.read @@configs_path
    data = JSON.parse file
    puts data
    data
  end
end
