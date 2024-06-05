# frozen_string_literal: true

require_relative 'skipper_client/version'
require_relative 'skipper_client/configs'
require_relative 'skipper_client/consumer'

module SkipperClient
  class Error < StandardError; end

  class CLI
    def initialize
      @cfg = Config.new
      puts @cfg.uri, @cfg.token

      consumer = Consumer.new @cfg
      valid = consumer.token_valid?
      puts valid
      consumer.products.data.each do |prod|
        puts prod.amount
      end
    end
  end
end
