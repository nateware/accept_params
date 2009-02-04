# Include hook code here
# NOTE: Must send() to :include since it's a private method
ActionController::Base.send :include, AcceptParams::Controller
