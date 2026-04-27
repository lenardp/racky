# The following is an example of a "service", i.e. a class where each instance
# does one thing and does it well.

class BowlOfCerealMaker
  include Service

  def initialize(cereal:, milk:)
    @cereal = cereal
    @milk = milk
  end

  def call
    validate_ingredients!
    pour_cereal
    pour_milk!

    bowl
  rescue => e
    report_error(e)
    empty_bowl
    bowl
  end

  private

  attr_accessor cereal, milk

  def on_error(e)
  end

  def validate_ingredients!
    raise "Cereal is stale" if is_expired?(cereal)
    raise "Milk is spoiled" if is_expired?(milk)
  end

  def pour_cereal
    FoodAdder.new(food: cereal, container: bowl).call
  end

  def pour_milk!
    LiquidAdder.new(liquid: milk, container: bowl).call!
  end

  def report_error(e)
    ErrorReporter.new(e).call
  end

  def empty_bowl
    BowlCleaner.new(bowl).call
    bowl
  end

  def is_expired?(ingredient)
    ExpiryChecker.new(ingredient).call
  end

  def bowl
    @bowl ||= begin
      existing_bowl = Bowl.medium_sized.clean.first
      return new_bowl if existing_bowl.blank?

      is_useable = BowlChecker.new(existing_bowl).call!
      return new_bowl unless is_useable

      existing_bowl
    rescue => e
      new_bowl
    end
  end

  def new_bowl
    BowlMaker.new.call
  end
end
