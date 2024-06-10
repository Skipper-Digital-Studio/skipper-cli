# frozen_string_literal: true

module Models
  # base request
  class JsonRequest
    def as_json
      raise "not implemented"
    end
  end

  # PriceID      string  `json:"price_id"`
  # Qty          int     `json:"quantity"`
  # CompanyName  string  `json:"company_name"`
  # ProjectName  string  `json:"project_name"`
  # CouponCode   *string `json:"coupon_code"`
  # ReferredCode *string `json:"referred_code"`
  class CheckouReq < JsonRequest
    attr_reader :price_id, :quantity, :company_name, :project_name, :coupon_code

    def initialize(price, quantity, company_name, project_name, coupon_code)
      @price = price
      @quantity = quantity
      @company_name = company_name
      @project_name = project_name
      @coupon_code = coupon_code
      super()
    end

    def as_json
      {
        price_id: @price.external_id,
        quantity: @quantity,
        company_name: @company_name,
        project_name: @project_name,
        coupon_code: @coupon_code
      }
    end
  end
end
