module Spree
  module Calculator::Shipping
    class WeightRates < ShippingCalculator
      preference :costs_string, :text, default: "1:5\n2:7\n5:10\n10:15\n100:50"
      preference :default_weight, :decimal, default: 1
      preference :upcharge, :decimal, default: 0
      preference :only_integers, :boolean, default: true

      def self.description
        Spree.t(:weight_rates)
      end

      def self.register
        super
      end

      def available?(package)
        return false if !costs_string_valid?

        true
      end

      def compute_package(package)
        # Products/Variants
        content_items = package.contents

        # Total cart weight
        total_weight  = total_weight(content_items)

        # Costs table
        costs = costs_string_to_hash(clean_costs_string)

        # Weight based on total cart weight
        weight_class = costs.keys.select { |w| total_weight <= w }.min || costs.keys.max

        # Price
        base_shipping_cost = costs[weight_class]

        # Fee per additional kilo
        upcharge_amount = 0
        if base_shipping_cost and weight_class < total_weight
          # Extra weight to be charged over shipment price
          extra_weight = (total_weight - weight_class)

          # Weight rounded for not using fractions of them
          extra_weight = extra_weight.ceil if preferred_only_integers

          upcharge_amount = preferred_upcharge * extra_weight
        end

        return base_shipping_cost + upcharge_amount
      end

      private
        def clean_costs_string
          preferred_costs_string.strip
        end

        def costs_string_valid?
          !clean_costs_string.empty? &&
          clean_costs_string.count(':') > 0 &&
          clean_costs_string.split(/\:|\n/).size.even? &&
          clean_costs_string.split(/\:|\n/).all? { |s | s.strip.match(/^\d|\.+$/) }
        end

        def costs_string_to_hash(costs_string)
          costs = {}

          costs_string.split.each do |cost_string|
            values = cost_string.strip.split(':')
            costs[values[0].strip.to_f] = values[1].strip.to_f
          end

          costs
        end

        def total_weight(contents)
          weight = 0

          # Compute weight for each cart item
          contents.each do |item|
            item_weight = item.variant.weight > 0.0 ? item.variant.weight : preferred_default_weight
            weight += item.quantity * item_weight
          end

          weight
        end
    end
  end
end
