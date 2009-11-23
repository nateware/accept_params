
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Controller
  include AcceptParams::Controller
  attr_reader :params
  def initialize(params={})
    @params = params
  end
end

#
# NOTE: It is very important that params be set a strings, because
# accept_params uses params.keys, which in HashWithIndifferentAccess (Rails)
# returns strings, NOT symbols
#

describe AcceptParams do
  it "should do handle basic param sets in happy-path conditions" do
    ctrl = Controller.new(
      'username' => 'taco',
      'password' => 'ecR9301912mbwiuwe'
    )
    ctrl.accept_params do |p|
      p.string :username
      p.string :password
    end
    
    ctrl = Controller.new(
      'user' => {
        'login' => 'burrito',
        'password' => 'wpwowencw',
        'id' => 29832
      }
    )
    ctrl.accept_params do |p|
      p.namespace :user do |u|
        u.string :login
        u.string :password
        u.integer :id
      end
    end
    
    ctrl = Controller.new(
      'id' => 8675301,
    )
    ctrl.accept_params do |p|
      p.integer :id
    end
    
    ctrl = Controller.new(
      'id' => 8675301,
    )
    ctrl.accept_params do |p|
      p.integer :id
      p.string :optional
    end    
  end
  
  it "should throw exceptions on params failures" do
    error = nil
    ctrl = Controller.new
    begin
      ctrl.accept_params do |p|
        p.string :username, :required => true
        p.string :password, :required => true
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::MissingParam)

    error = nil
    ctrl = Controller.new(
      'id' => '---*ABC*---',
    )
    begin
      ctrl.accept_params do |p|
        p.integer :id
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::InvalidParamType)
    
  end
  
  
  
end