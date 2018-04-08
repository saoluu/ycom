class Plugins::Ecommerce::ShippingMethod < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :ecommerce_shipping_method) }
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id
  scope :actives, -> {where(status: '1')}

  def skip_slug_validation?
    true
  end

  def get_price_from_weight(weight = 0)
    price_total = 0
    prices = get_meta("prices")
    if prices.present?
      prices.each do |key, value|
        price_total = value[:price] if value[:min_weight].to_f <= weight.to_f && value[:max_weight].to_f >= weight.to_f
      end
    end
    price_total.to_f
  end

end
