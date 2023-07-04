require "json"
require "net/http"
require 'pry'
# require './evaluation'

class TrustIn
  def initialize(evaluations)
    @evaluations = evaluations
  end

  def update_score
    @evaluations.each do |evaluation|

      if evaluation.type == "SIREN"
        update_siren_companies(evaluation)
      end

      if evaluation.type == 'VAT'
        update_vat_companies(evaluation)
      end
    end
  end

  def update_siren_companies(evaluation)
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
        return unless parsed_response

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

  def update_vat_companies(evaluation)
    company_state = parsed_response["records"]&.first&.dig('fields')&.dig("etatadministratifetablissement")

    if evaluation.score >= 50 
      evaluation.value -= 1
    else
      evaluation.value -= 3
    end

  end

  def api_response(value)
    uri = URI("https://public.opendatasoft.com/api/records/1.0/search/?dataset=sirene_v3" \
          "&q=#{value}&sort=datederniertraitementetablissement" \
          "&refine.etablissementsiege=oui")
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)

  # rescue StandardError
  #   puts 'unable to reach Api'
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

