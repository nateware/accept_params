
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Controller
  include AcceptParams::Controller
  attr_reader :params
  def initialize(params={})
    @params = params
  end
end

describe AcceptParams do
  it "should do handle basic param sets in happy-path conditions" do
    ctrl = Controller.new(
      :username => 'taco',
      :password => 'ecR9301912mbwiuwe'
    )
    ctrl.accept_params do |p|
      p.string :username
      p.string :password
    end
    
    ctrl = Controller.new(
      :user => {
        :login => 'burrito',
        :password => 'wpwowencw',
        :id => 29832
      }
    )
    
    
  end
  
  
  
end