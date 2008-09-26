module AcceptParams
  module Controller
    def accept_params(settings={}, &block) #:yields: param
      raise NoParamsDefined, "Missing block for accept_params" unless block_given?
      safe_assertion do
        rules = ParamRules.new(settings)
        yield rules
        rules.validate(params)
      end
    end

    # Shortcut functions to tighten up security further
    def accept_no_params
      accept_params {}
    end
    
    def accept_only_id
      accept_params do |p|
        p.integer :id, :required => true
      end
    end

    # Run the given code wrapped in a rescue block, so that we temporarily trap 
    # and log any RequestError exceptions that get raised.
    def safe_assertion
      yield
    rescue ParamError
      logger.error "Bad request: #{$!}" 
      raise        
    end    
    
    # This is what you have to do to mixin class methods (eg, self.whatever). sucks.
    def self.included(base)
      base.extend  ClassMethods
    end
    
    module ClassMethods
      # For rule caching
      def cache_accept_params_rules(rules)
        raise NotImplementedError, "caching not yet implemented"
        write_inheritable_attribute :cache_accept_params_rules, rules
      end
    end
  end
end