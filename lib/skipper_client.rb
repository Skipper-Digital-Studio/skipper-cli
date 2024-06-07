# frozen_string_literal: true

require_relative 'skipper_client/version'
require_relative 'skipper_client/configs'
require_relative 'skipper_client/consumer'
require 'tty-prompt'
require 'cli/ui'

module SkipperClient
  class Error < StandardError; end

  class Clippy
    def initialize
      @cfg = Config.new
      @consumer = Consumer.new @cfg
      @cached_products = []
    end

    def products
      return @cached_products unless @cached_products.empty?

      @cached_products = @consumer.products.data
      @cached_products
    end

    def product_from_prompt(str_product)
      str_product.include?('WEEKLY') ? weekly_product : monthly_product
    end

    def run
      CLI::UI::StdoutRouter.enable
      CLI::UI::Frame.open('SKIPPER DIGITAL STUDIO') do
        product = nil
        CLI::UI::Prompt.ask('Choose the subscription model you want') do |handler|
          # handler.option('weekly -> ') { |selection| selection }
          prompt_products.each do |prompt|
            handler.option(prompt[:prompt]) do |_|
              product = prompt[:value]
            end
          end
        end
        amount = CLI::UI::Prompt.ask('How many workstreams you want?', default: '1').to_i

        company_name = CLI::UI::Prompt.ask("What's your company name?", allow_empty: false)
        project_name = CLI::UI::Prompt.ask("What's your project name?", allow_empty: false)

        discount_coupon = CLI::UI::Prompt.ask('Input a discount coupon if you have one / (Not required)')
        discount = discount_coupon != '' && @consumer.valid_coupon?(discount_coupon) ? discount_coupon : nil

        continue = false
        CLI::UI::Frame.open('Subscription details') do
          puts CLI::UI.fmt "{{info: Company Name -> #{company_name} }}"
          puts CLI::UI.fmt "{{info: Project Name -> #{project_name} }}"
          puts CLI::UI.fmt "{{info: Number of workflows -> #{amount} }}"
          puts CLI::UI.fmt "{{success: Total = #{product.currency} #{(amount * product.amount - (discount.nil? ? 0 : discount.amount)) / 100} }}"

          continue = CLI::UI::Prompt.confirm 'Continue to checkout?', default: true
        end

        return unless continue

        session = nil
        CLI::UI::Frame.open('CHECKOUT') do
          CLI::UI::SpinGroup.new do |spin_group|
            spin_group.add('Generating checkout session') do |_|
              session = @consumer.checkout Models::CheckouReq.new(product, amount, company_name, project_name,
                                                                  discount)
            end
          end
        end

        IO.popen('pbcopy', 'w') { |f| f << session.data.payment_url }
        puts CLI::UI.fmt '{{success: Checkout URL copied to your clipboard }}'
      end
    end

    private

    def prompt_products
      products.map do |product|
        { prompt: "#{product.billing_schema.upcase} -> #{product.currency} #{product.amount / 100}", value: product }
      end
    end

    def weekly_product
      products.find { |p| p.billing_schema == 'weekly' }
    end

    def monthly_product
      products.find { |p| p.billing_schema == 'monthly' }
    end
  end
end
