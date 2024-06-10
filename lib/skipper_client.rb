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

    def run
      CLI::UI::StdoutRouter.enable
      CLI::UI::Frame.open('SKIPPER DIGITAL STUDIO') do
        puts CLI::UI.fmt title
        fetch_products
        product, amount, company_name, project_name, discount = subscription_form
        subscription_details product, amount, company_name, project_name, discount
        unless CLI::UI::Prompt.confirm 'Continue to checkout?', default: true
          puts CLI::UI.fmt '{{error:Checkout canceled }}'
          puts CLI::UI.fmt 'Thank you for using Clippy the Skipper Command Line Application'
          return
        end

        session = checkout product, amount, company_name, project_name, discount
        success_output session
      end
    end

    def title
      "
    __|__ |___| |\\
    |o__| |___| | \\
    |___| |___| |o \\
   _|___| |___| |__o\\
  /...\\_____|___|____\\_/
  \\   o * o * * o o  /
~~~~~~~~~~~~~~~~~~~~~~~~~~

"
    end

    def products
      return @cached_products unless @cached_products.empty?

      @cached_products = @consumer.products.data
      @cached_products
    end

    def product_from_prompt(str_product)
      str_product.include?('WEEKLY') ? weekly_product : monthly_product
    end

    def success_output(session)
      puts CLI::UI.fmt " {{success: checkout session created: \n #{session.data.payment_url} \n Open the ssession on any broweser you want}}"
      puts CLI::UI.fmt "\n {{success: Thank you for Using Clippy - The Command line tool to work with Skipper Digital Studio }}"
    end

    def subscription_form
      product = nil
      CLI::UI::Frame.open('SUBSCRIPTION FORM') do
        CLI::UI::Prompt.ask('Choose the subscription model you want') do |handler|
          prompt_products.each do |prompt|
            handler.option(prompt[:prompt]) do |_|
              product = prompt[:value]
            end
          end
        end
        [product, cli_amount, cli_company_name, cli_project_name, cli_discount]
      end
    end

    def subscription_details(product, amount, company_name, project_name, discount)
      CLI::UI::Frame.open('Subscription details') do
        puts CLI::UI.fmt "{{info: Company Name -> #{company_name} }}"
        puts CLI::UI.fmt "{{info: Project Name -> #{project_name} }}"
        puts CLI::UI.fmt "{{info: Number of workflows -> #{amount} }}"
        unless discount.nil?
          puts CLI::UI.fmt "\n{{info: Discount coupon applied '#{discount}' = 5% for the first 3 months}}"
        end
        net_amount = product.amount * amount
        customer_res = (@consumer.customer_by_company_and_project company_name, project_name)
        puts CLI::UI.fmt "\n{{info: New customer discount applied 45% for the first 3 months}}" if customer_res.nil?
        new_customer_disc = customer_res.nil? ? 0.45 : 0.0
        coupon_discount = discount.nil? ? 0.0 : 0.05
        total = net_amount * (1 - coupon_discount - new_customer_disc)
        puts CLI::UI.fmt "\n{{success: Total = #{product.currency} #{(total / 100).round} (First 3 months) - Then #{product.currency} #{net_amount / 100} }}"
      end
    end

    def checkout(product, amount, company_name, project_name, discount)
      session = nil
      CLI::UI::Frame.open('CHECKOUT') do
        CLI::UI::SpinGroup.new do |spin_group|
          spin_group.add('Generating checkout session') do |_|
            session = @consumer.checkout Models::CheckouReq.new(product, amount, company_name, project_name,
                                                                discount)
          end
        end
      end
      session
    end

    def fetch_products
      CLI::UI::SpinGroup.new do |spin_group|
        spin_group.add('Fetching all the products') do |_|
          products
        end
      end
    end

    private

    def validate_string(str)
      special = "?<>',?[]}{=-)(*&^%$#`,.~{}"
      regex = /[#{special.gsub(/./) { |char| "\\#{char}" }}]/
      !(str =~ regex)
    end

    def string_prompt(prompt_text, is_retry)
      puts CLI::UI.fmt 'Invalid input. The text cannot contain any special character or . (dot) | , (comma)' if is_retry
      CLI::UI::Prompt.ask prompt_text, allow_empty: false
    end

    def cli_amount
      CLI::UI::Prompt.ask('How many workstreams you want?', default: '1').to_i
    end

    def cli_company_name
      output = string_prompt "What's your company name?", false
      loop do
        break if validate_string output

        output = string_prompt "What's your company name?", true
      end
      output
    end

    def cli_project_name
      output = string_prompt "What's your project name?", false
      loop do
        break if validate_string output

        output = string_prompt "What's your project name?", true
      end
      output
    end

    def cli_discount
      output = nil
      CLI::UI::Frame.open('DISCOUNT FORM') do
        discount_coupon = cli_discount_loop
        output = discount_coupon != '' ? discount_coupon : nil
      end
      output
    end

    def cli_discount_loop
      loop do
        discount_coupon = CLI::UI::Prompt.ask('Input a discount coupon if you have one / (Not required)')
        return '' unless discount_coupon != ''

        valid = valid_coupon? discount_coupon
        return discount_coupon if valid

        next if cli_should_try_again_discount

        puts CLI::UI.fmt '{{info: Continuing without a discount coupon}}'
        break
      end
    end

    def cli_should_try_again_discount
      CLI::UI::Prompt.ask 'The coupon was not a valid one. What you want to do?' do |handler|
        handler.option('Use a different coupon?') { |_| true }
        handler.option('Continue without a coupon?') { |_| false }
      end
    end

    def valid_coupon?(discount_coupon)
      final_glyph = ->(success) { success ? CLI::UI::Glyph::CHEVRON.to_s : CLI::UI::Glyph::X.to_s }
      valid = false
      CLI::UI::SpinGroup.new do |spin_group|
        spin_group.add 'Validating coupon', final_glyph: final_glyph do |spinner|
          valid = @consumer.valid_coupon?(discount_coupon)
          spinner.update_title CLI::UI.fmt "{{error: Discount coupon #{discount_coupon} is Invalid }}" unless valid
        end
      end
      valid
    end

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
