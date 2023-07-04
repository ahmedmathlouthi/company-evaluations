class Evaluation
    
    attr_accessor :type, :value, :score, :state, :reason
  
    TYPES = %w[SIREN VAT].freeze
    STATES = %w[favorable unfavorable unconfirmed].freeze
    REASONS = %w[unable_to_reach_api company_closed ongoing_database_update company_opened].freeze
  
    def initialize(type:, value:, score:, state:, reason:)
      @type = validate_type(type)
      @value = value
      @score = validate_score(score)
      @state = validate_state(state)
      @reason = validate_reason(reason)
    end
  
    def to_s()
      "#{@type}, #{@value}, #{@score}, #{@state}, #{@reason}"
    end
  
    def validate_score(score)
      if score < 0
        raise StandardError => e
          e.message = 'cant go below 0'
      end

      score
    end

    def validate_type(type)
      unless TYPES.include? type
        raise StandardError.new("type must be in #{TYPES.join(',')}")
      end

      type
    end

    def validate_state(state)
      unless STATES.include? state
        raise StandardError.new("state must be in #{STATES.join(',')}")
      end

      state
    end

    def validate_reason(reason)
      unless REASONS.include? reason
        raise StandardError.new("reason must be in #{REASONS.join(',')}")
      end

      reason
    end
  end
  