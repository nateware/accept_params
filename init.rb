# Include hook code here
# NOTE: Must send() to :include since it's a private method
require 'accept_params'
ActionController::Base.send :include, AcceptParams::Controller