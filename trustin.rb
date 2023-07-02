require "json"
require "net/http"
require 'pry'

class TrustIn
  def initialize(evaluations)
    @evaluations = evaluations
  end

  def update_score
    @evaluations.each do |evaluation|
      next unless evaluation.type == "SIREN"

      if evaluation.score > 0 && evaluation.state == "unconfirmed" && evaluation.reason == "ongoing_database_update"
        parsed_response = api_response(evaluation.value)

        company_state = parsed_response["records"]&.first&.dig('fields')&.dig("etatadministratifetablissement")
        
        if company_state == "Actif"
          evaluation.state = "favorable"
          evaluation.reason = "company_opened"
          evaluation.score = 100
        else
          evaluation.state = "unfavorable"
          evaluation.reason = "company_closed"
          evaluation.score = 100
        end
      elsif evaluation.score >= 50
        if evaluation.state == "unconfirmed" && evaluation.reason == "unable_to_reach_api"
          evaluation.score -= 5
        elsif evaluation.state == "favorable"
          evaluation.score -= 1
        end
      elsif evaluation.score <= 50 && evaluation.score > 0 
        if evaluation.state == "unconfirmed" && evaluation.reason == "unable_to_reach_api" || evaluation.state == "favorable"
          evaluation.score -= 1
        end
      else

        if evaluation.state == "favorable" || evaluation.state == "unconfirmed"
          parsed_response = api_response(evaluation.value)
          next unless parsed_response

          company_state = parsed_response["records"]&.first&.dig('fields')&.dig("etatadministratifetablissement")
          
          if company_state == "Actif"
            evaluation.state = "favorable"
            evaluation.reason = "company_opened"
            evaluation.score = 100
          else
            evaluation.state = "unfavorable"
            evaluation.reason = "company_closed"
            evaluation.score = 100
          end
        end
      end
    end
  end

  def api_response(value)
    uri = URI("https://public.opendatasoft.com/api/records/1.0/search/?dataset=sirene_v3" \
          "&q=#{value}&sort=datederniertraitementetablissement" \
          "&refine.etablissementsiege=oui")
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)

    raise UndefinedSirenError.new(value) unless parsed_response.dig('error').nil?
  end
end

class UndefinedSirenError < StandardError

  def initialize(value)
    @value = value
  end

  def message 
    "The siren given #{@value} is not known"
  end
end

class Evaluation
  attr_accessor :type, :value, :score, :state, :reason

  TYPES = %w[SIREN].freeze
  STATES = %w[favorable unfavorable unconfirmed].freeze
  REASONS = %w[unable_to_reach_api company_closed ongoing_database_update company_opened].freeze

  def initialize(type:, value:, score:, state:, reason:)
    @type = type
    @value = value
    @score = score
    @state = state
    @reason = reason
  end

  def to_s()
    "#{@type}, #{@value}, #{@score}, #{@state}, #{@reason}"
  end

  # def state=(str)
  #   @state = STATES.index(str)
  # end

  # def state
  #   STATES[@state]
  # end

  # def type=(str)
  #   @type = TYPES.index(str)
  # end

  # def type
  #   TYPES[@type]
  # end

  # def reason=(str)
  #   @reason = REASONS.index(str)
  # end

  # def reason
  #   REASONS[@reason]
  # end
end
