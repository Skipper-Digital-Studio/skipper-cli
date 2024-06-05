# frozen_string_literal: true

require 'uri'
require 'json'
require 'http'
require_relative '../models/models'

# cosumer
class Consumer
  attr_reader :cfg

  def initialize(cfg)
    @cfg = cfg
  end

  def content_type
    { 'Content-Type' => 'application/json' }
  end

  def token_valid?
    auth_uri = URI "#{uri}/auth/validate/#{token}"
    begin
      response = SkipperResponse.from_response HTTP.get(auth_uri), ValidApiKeyResponse
      puts response
      true
    rescue StandardError => e
      puts e
      false
    end
  end

  def create_api_key
    new_token_api = URI "#{uri}/internal/management/api_key"
    req = HTTP.Post.new new_token_api.path, contest_type
    req.body = { origin: '*', name: 'new_api_key', purpose: 'general' }
    SkipperResponse.from_response HTTP.request(req), ApiKeyResponse
  end

  def products
    products_uri = URI "#{uri}/api/v1/products"
    puts products_uri
    SkipperResponse.from_response HTTP.headers("x-api-key": token).get(products_uri), Price, :list
  end

  def product(id)
    products.data.find { |d| d.external_id == id }
  end

  def coupon(coupon)
    coupon_uri = URI "#{uri}/api/v1/products/coupons/#{coupon}"
    req = HTTP.Get.new coupon_uri.path
    SkipperResponse.from_response HTTP.request(req), Coupon, :unit
  end

  def uri
    @cfg.uri
  end

  def token
    @cfg.token
  end

  private

  def body_to_json(body)
    JSON.parse! body
  end
end
