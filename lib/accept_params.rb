# AcceptParams
require 'active_support/core_ext'
module AcceptParams
  # Exceptions for AcceptParams
  class ParamError < StandardError; end #:nodoc:
  class NoParamsDefined   < ParamError; end #:nodoc:
  class MissingParam      < ParamError; end  #:nodoc:
  class UnexpectedParam   < ParamError; end  #:nodoc:
  class InvalidParamType  < ParamError; end  #:nodoc:
  class InvalidParamValue < ParamError; end  #:nodoc:
  
  # Below here are settings that can be modified in environment.rb
  # Whether or not to cache rules for performance.
  mattr_accessor :cache_rules
  @@cache_rules = false
  
  # The list of params that we should allow (but not require) by default. It's as if we
  # said that all requests may_have these elements. By default this
  # list is set to:
  #
  # * action
  # * controller
  # * commit
  # * _method
  #
  # You can modify this list in your environment.rb if you need to. Always
  # use strings, not symbols for the elements. Here's an example:
  #
  #   AcceptParams::ParamRules.ignore_params << "orientation"
  #
  mattr_accessor :ignore_params
  @@ignore_params = %w( action controller commit format _method authenticity_token )

  # The columns in ActiveRecord models that we should ignore by
  # default when expanding an is_a directive into a series of 
  # must_have directives for each attribute. These are the 
  # attributes that are almost never present in your forms (and hence your params).
  # By default this list is set to:
  #
  # * id
  # * created_at
  # * updated_at
  # * created_on
  # * updated_on
  # * lock_version
  #
  # You can modify this in your environment.rb if you have common attributes
  # that should always be ignored. Here's an example:
  #
  #   AcceptParams::ParamRules.ignore_columns << "deleted_at"
  #
  mattr_accessor :ignore_columns
  @@ignore_columns = %w( id created_at updated_at created_on updated_on lock_version )

  # If unexpected params are encountered, default behavior is to raise an exception
  # Setting this to true will instead just all them on through.  Note this defeats
  # much of the purpose of the plugin. To mitigate security issues, try setting the
  # next flag to "true" if you set this to true.
  mattr_accessor :ignore_unexpected
  @@ignore_unexpected = false

  # If unexpected params are encountered, remove them to prevent injection attacks.
  # Note: This is only relevant if you set ignore_unexpected to true, in which case
  # you can have them removed (safer) by setting this. The basic idea is that then
  # an exception won't be raised, but an attacker still won't be able to inject params.
  mattr_accessor :remove_unexpected
  @@remove_unexpected = false
  
  # How to validate parameters
  mattr_accessor :type_validations
  @@type_validations = {
    :string  => /^.*$/,
    :text    => /^.*$/,
    :binary  => /^.*$/,
    :integer => /^-?\d+$/,
    :float   => /^-?(\d*\.\d+|\d+)$/,
    :decimal => /^-?(\d*\.\d+|\d+)$/,
    :boolean => /^(1|true|TRUE|T|Y|0|false|FALSE|F|N)$/,
    :datetime => /^[-\d:T\s]+$/,  # "T" is for ISO date formats
  }
end
require 'accept_params/controller'
require 'accept_params/param_rules'
