# frozen_string_literal: true

require 'minitest/autorun'
require 'timeout'

class CustomerSuccessBalancing
  attr_accessor :customer_success, :customers, :away_customer_success

  def initialize(customer_success, customers, away_customer_success)
    @customer_success = customer_success
    @customers = customers
    @away_customer_success = away_customer_success
  end

  # Returns the id of the CustomerSuccess with the most customers
  def execute
    customer_success_calculated = quantity_served_customers_sorted_by_cs
    biggest_served = customer_success_calculated.first
    return 0 if draw_between_quantity_served_customers?(customer_success_calculated)

    biggest_served[:id]
  end

  private

  def quantity_served_customers_sorted_by_cs
    calculate_quantity_served_customers_by_cs.sort_by { |cs| cs[:served_customers_quantity] }.reverse
  end

  def calculate_quantity_served_customers_by_cs
    sorted_available_customer_success.reverse_each.map do |customer_success|
      { id: customer_success[:id], served_customers_quantity: served_customers_quantity(customer_success) }
    end
  end

  def served_customers_quantity(customer_success)
    previous_customer_success_score = find_previous_customer_success_score(customer_success)
    customers.count { |cus| cus[:score] > previous_customer_success_score && cus[:score] <= customer_success[:score] }
  end

  def find_previous_customer_success_score(customer_success)
    previous_index = sorted_available_customer_success.index { |cs| cs[:id] == customer_success[:id] } - 1
    previous_customer_success = sorted_available_customer_success[previous_index]
    return 0 if previous_index.negative?

    previous_customer_success[:score]
  end

  def draw_between_quantity_served_customers?(customer_success_calculated)
    customer_success_calculated[0][:served_customers_quantity] ==
      customer_success_calculated[1][:served_customers_quantity]
  end

  def available_customer_success
    customer_success.reject { |cs| away_customer_success.include?(cs[:id]) }
  end

  def sorted_available_customer_success
    @sorted_available_customer_success ||= available_customer_success.sort_by { |cs| cs[:score] }
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  def test_scenario_one
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array.new(10_000, 998)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 998, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(
      build_scores([1, 2, 3, 4, 5, 6]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 2, 3, 6, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [1, 3, 2]
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [4, 5, 6]
    )
    assert_equal 3, balancer.execute
  end

  private

  def build_scores(scores)
    scores.map.with_index do |score, index|
      { id: index + 1, score: score }
    end
  end
end
