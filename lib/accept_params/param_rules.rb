module AcceptParams
  # This class is used to declare the structure of the params hash for this
  # request.
  class ParamRules
    attr_reader :name, :parent, :children, :options, :type, :settings #:nodoc:

    # TODO: Convert this to a hash of options.
    def initialize(settings, type=nil, name=nil, options={}, parent=nil) # :nodoc:
      @children = []
      @options  = options
      if name.nil?
        @name = @type = @parent = nil
        # Set default options which control behavior
        @settings = {
          :ignore_unexpected => AcceptParams.ignore_unexpected,
          :remove_unexpected => AcceptParams.remove_unexpected,
          :ignore_params     => AcceptParams.ignore_params,
          :ignore_columns    => AcceptParams.ignore_columns,
        }.merge(settings)
      else
        if parent.nil? or type.nil?
          raise ArgumentError, "name, type, and parent must all be either nil or not nil"
        end
        @type   = type.to_sym
        @parent = parent

        if is_model?(name)
          klass = name
          @name = klass.to_s.underscore.to_sym
          is_a klass
        else
          @name = name.to_sym
        end
        
        # This is undocumented, and specific to SCEA
        if @options.has_key? :to_id
          klass = @options[:to_id]
          @options[:process] = Proc.new{|v| klass.to_id(v)}
          @options[:to] = "#{@name}_id"
        end
      end
    end
    
    # Allow nesting
    def namespace(name, &block)
      raise ArgumentError, "Missing block to param namespace declaration" unless block_given?
      child = ParamRules.new(settings, :namespace, name, {:required => false}, self)  # block not required per se
      yield child
      @children << child
    end

    # Ala pretty migrations
    def string(name, options={})
      param(:string, name, options)
    end
    def integer(name, options={})
      param(:integer, name, options)
    end
    def float(name, options={})
      param(:float, name, options)
    end
    def decimal(name, options={})
      param(:decimal, name, options)
    end
    def boolean(name, options={})
      param(:boolean, name, options)
    end
    def datetime(name, options={})
      param(:datetime, name, options)
    end
    def text(name, options={})
      param(:text, name, options)
    end
    def binary(name, options={})
      param(:binary, name, options)
    end
    def array(name, options={})
      param(:array, name, options)
    end
    
    # This is a shortcut for declaring elements that represent ActiveRecord
    # classes. Essentially, it creates a declaration for each
    # attribute of the given model (excluding the ones in the class
    # attribute ignore_columns, which is described at the top of this page).
    def model(klass)
      unless is_model?(klass)
        raise ArgumentError, "Must supply an ActiveRecord class to the model method"
      end
      klass.columns.each do |c|
        param(c.type, c.name, :required => c.null, :limit => c.limit) unless ignore_column?(c)
      end
    end

    # Is this a required params element? Implies "must_have".
    def required? #:nodoc:
      options[:required]
    end
    
    def namespace?
      type == :namespace
    end
    
    # Returns the full name of this parameter as it would be accessed in the
    # action. Example output might be "params[:person][:name]". 
    def canonical_name #:nodoc:
      if parent.nil?
        ""
      elsif parent.parent.nil?
        name
      else
        parent.canonical_name + "[#{name}]" 
      end
    end
    
    # Validate the given parameters against our requirements, raising 
    # exceptions for missing or unexpected parameters.
    def validate(params) #:nodoc:
      recognized_keys = validate_children(params)
      unexpected_keys = params.keys - recognized_keys
      if parent.nil?
        # Only ignore the standard params at the top level.
        unexpected_keys -= settings[:ignore_params]
      end
      unless unexpected_keys.empty?
        # kinda hacky to get it to display correctly
        unless settings[:ignore_unexpected]
          basename   = canonical_name
          canonicals = unexpected_keys.collect{|k| basename.empty? ? k : basename + "[#{k}]"}.join(', ')
          raise UnexpectedParam, "Request included unexpected parameter(s): #{canonicals}"
        end
        unexpected_keys.each{|k| params.delete(k)} if settings[:remove_unexpected]
      end
    end
    
    # Create a new param
    def param(type, name, options)
      @children << ParamRules.new(settings, type, name, options, self)
    end

    private
    
    # Should we ignore this ActiveRecord column? 
    def ignore_column?(column)
      settings[:ignore_columns].detect { |name| name == column.name }
    end
    
    # Determine if the given class is an ActiveRecord model.
    def is_model?(klass)
      klass.respond_to?(:ancestors) &&
        klass.ancestors.detect {|a| a == ActiveRecord::Base || a == MongoRecord::Base}
    end
    
    # Remove the given children. 
    def remove_child(*names)
      names.each do |name|
        children.delete_if { |child| child.name == name }
      end          
    end
   
    # Validate our children against the given params, looking for missing 
    # required elements. Returns a list of the keys that we were able to
    # recognize.
    def validate_children(params)
      recognized_keys = []
      children.each do |child|
        #puts ">>>>>>>>>> child.name = #{child.canonical_name}"
        if child.namespace?
          recognized_keys << child.name
          # NOTE: Can't get fancy and do this ||= w/i the below func call, due to 
          # an apparent oddity of Ruby's scoping for method args
          params[child.name] ||= HashWithIndifferentAccess.new   # create holder for subelements if missing
          validate_child(child, params[child.name]) 
        elsif params.has_key?(child.name)
          recognized_keys << child.name
          validate_child(child, params[child.name])
          validate_value_and_type_cast!(child, params)
        elsif child.required?
          raise MissingParam, "Request params missing required parameter '#{child.canonical_name}'"
        else
          # For setting defaults on missing parameters
          recognized_keys << child.name
          validate_value_and_type_cast!(child, params)
        end

        # Finally, handle key renaming
        if new_name = child.options[:to]
          # Removed this because it causes havok with :to_id and will_paginate.
          # Not needed anyways, since we just overwrite it right afterwards.
          # if params.has_key? new_name
          #   raise UnexpectedParam, "Request included destination parameter '#{new_name}'"
          # end
          params[new_name] = params.delete(child.name)
          recognized_keys << new_name
        end  
      end
      #puts "!!!!!!!!! DONE: params[:filters] = #{params[:filters].inspect}; #{params[:filters].object_id}"
      recognized_keys
    end
    
    # Validate this child against its matching value. In addition, manipulate the params
    # hash as-needed to set any applicable default values.
    def validate_child(child, value)
      if child.children.empty?
        if value.is_a?(Hash)
          raise UnexpectedParam, "Request parameter '#{child.canonical_name}' is a hash, but wasn't expecting it"
        end
      else
        if value.is_a?(Hash)
          #puts "????????? NEST: #{value.inspect} (#{value.object_id})"
          child.validate(value)  # recurse
        else
          raise InvalidParamValue, "Expected parameter '#{child.canonical_name}' to be a nested hash"
        end
      end
    end

    def validate_value_and_type_cast!(child, params)
      return true if child.namespace?
      value = params[child.name] # we may be recursive, eg, params[:filters][:player_creation_type]
      #puts "@@@@@@@@@@@@ VALUE(#{child.canonical_name}) = #{value.inspect}"

      # XXX Special catch for pagination with :to_id fields, since "player_creation_type"
      # becomes player_creation_type_id (with the correct value) on subsequent pages
      #puts "@@@ #{child.canonical_name}: if #{value.nil?} and #{options[:to]} and #{params[options[:to]]} (#{options.inspect})"
      if value.nil? and to = child.options[:to] and params[to]
        value = params[to]
      elsif value.nil?
        if child.options.has_key?(:default)
          if child.options[:default].is_a? Proc
            begin
              value = child.options[:default].call
            rescue Exception => e
              # Rebrand exceptions so top-level can catch
              raise InvalidParamValue, e.to_s
            end
          else
            value = child.options[:default]
          end
        elsif child.required?
          raise InvalidParamValue, "Value for parameter '#{child.canonical_name}' is null or missing"
        else
          # If no default, that means it's *really* optional
          return true
        end
      elsif child.options.has_key?(:process)
        # Only call the process method if we're *not* using a default value
        # Must *NOT* type cast this value, or else it will be cast back to the
        # input value type (eg, string), rather than the :to_id type (integer)
        begin
          #puts ">>>>>>> #{value.inspect}, #{params.inspect}"
          value = child.options[:process].call(value)
          #puts ">>>>>>> #{value.inspect}, #{params.inspect}"
        rescue Exception => e
          # Rebrand exceptions so top-level can catch
          raise InvalidParamValue, e.to_s
        end
      elsif child.type == :array
        value = value.split(',') if value.is_a? String  # accept comma,delimited,string also
        unless value.is_a? Array
          raise InvalidParamType, "Value for parameter '#{child.canonical_name}' (#{value}) is of the wrong type (expected #{child.type})"
        end
      else
        # Validate and typecast non-defaults; assume the programmer was smart enough
        # to say :default => 4 rather than :default => "4" if using defaults
        validation = AcceptParams.type_validations[child.type] || raise(ParamError, "Internal error: Missing validation for param type #{child.type}")
        unless value.to_s =~ validation
          raise InvalidParamType, "Value for parameter '#{child.canonical_name}' (#{value}) is of the wrong type (expected #{child.type})"
        end
        value = type_cast_value(child.type, value)
        optional_extended_validations(child.canonical_name, value, child.options)
      end

      # Overwrite our original value, to make params safe
      params[child.name] = value
      #puts "+++++++++ #{child.canonical_name}: params[#{child.name}] = #{value.inspect} (#{params.object_id})"
    end

    def type_cast_value(type, value)
      case type
      when :integer
        value.to_i
      when :float, :decimal
        value.to_f
      when :string
        value.to_s
      when :boolean
        if value.is_a? TrueClass
          true
        elsif value.is_a? FalseClass
          false
        else
          case value
          when /^(1|true|TRUE|T|Y)$/
            true
          when /^(0|false|FALSE|F|N)$/
            false
          else
            raise InvalidParamValue, "Could not typecast boolean to appropriate value"
          end
        end
      when :binary, :array
        value
      else
        value.to_s
      end
    end

    def optional_extended_validations(name, value, options)
      # XXX This probably needs to go into integer/float-specific code somewhere
      if options[:minvalue] && value.to_i < options[:minvalue]
        raise InvalidParamValue, "Value for parameter '#{name}' (#{value}) is less than minimum value (#{options[:minvalue]})"
      end
      if options[:maxvalue] && value.to_i > options[:maxvalue]
        raise InvalidParamValue, "Value for parameter '#{name}' (#{value}) is more than maximum value (#{options[:maxvalue]})"
      end

      # This is general-purpose, but still feels like it should be in a separate method
      if options[:in] && !options[:in].include?(value)
        raise InvalidParamValue, "Value for parameter '#{name}' (#{value}) is not in the allowed set of values"
      end
    
      # XXX This probably needs to go into string-specific code somewhere
      if options[:maxlength] && value.length > options[:maxlength]
        raise InvalidParamValue, "Length of parameter '#{name}' (#{value.length}) is longer than maximum length (#{options[:maxlength]})"
      end

      # XXX This else statement is getting far too long....
      if options[:validate] && value.to_s !~ options[:validate]
        format_info = options[:format] and format_info = " (format: #{format_info})"
        raise InvalidParamValue, "Invalid value for parameter '#{name}'#{format_info}"
      end

      # Finally, if :null => false, this is a special sanity check that it can't be empty
      # This is designed to catch cases where the default/etc are null; it's a double-condom for programmers
      if (value.nil? || value == "") && (options.has_key?(:null) && options[:null] == false)
        raise InvalidParamValue, "Value for parameter '#{name}' is null or missing"
      end
    end
  end
end
