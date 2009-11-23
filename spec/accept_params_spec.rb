
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
    ctrl.params.has_key?('optional').should be_false

    ctrl = Controller.new(
      'id' => 8675301,
    )
    ctrl.accept_params do |p|
      p.integer :id
      p.string :optional, :default => 42
    end
    ctrl.params.has_key?('optional').should be_true
    ctrl.params['optional'].should == 42
    
    ctrl = Controller.new(
      'id' => 8675301,
      'optional'  => 989,
      'optional2' => 999,
      'check3' => 'true',
      'color' => 'red',
      'page'  => '1',
      'per_page' => '20',
      'food' => {
        'type_id' => 5
      }
    )
    ctrl.accept_params do |p|
      p.integer :id
      p.string :optional, :default => 42
      p.integer :optional2, :default => 43
      p.boolean :check, :required => false
      p.boolean :check2, :default => false
      p.boolean :check3, :default => false
      p.string :color, :in => %w(red green blue)
      p.namespace :food do |f|
        f.integer :type_id, :in => 1..9
      end
      p.integer :page, :minvalue => 1
      p.integer :per_page, :required => true
    end

    ctrl.params['optional'].should == "989"
    ctrl.params['optional2'].should == 999
    ctrl.params.has_key?('check').should be_false
    ctrl.params['check'].should be_nil
    ctrl.params['check2'].should be_false
    ctrl.params['check3'].should be_true
    ctrl.params['color'].should == 'red'
    ctrl.params['page'].should == 1
    ctrl.params['per_page'].should == 20
    
    ctrl = Controller.new(
      'users' => ['one','two','three']
    )
    ctrl.accept_params do |p|
      p.array :users
    end
    
  end
  
  it "should throw exceptions on params failures" do
    error = nil
    ctrl = Controller.new
    begin
      ctrl.accept_params do |p|
        p.string :username, :required => true, :default => 'nate'
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

    error = nil
    ctrl = Controller.new(
      'id' => '---*ABC*---',
    )
    begin
      ctrl.accept_params do |p|
        p.integer :id, :default => 101
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::InvalidParamType)
    error.to_s.should =~ /\bid\b/
    
    error = nil
    ctrl = Controller.new(
      'badbool' => '-13',
    )
    begin
      ctrl.accept_params do |p|
        p.boolean :badbool, :required => true
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::InvalidParamType)
    error.to_s.should =~ /\bbadbool\b/

    error = nil
    ctrl = Controller.new(
      'nested' => {
        'badfloat' => 'thursday',
      }
    )
    begin
      ctrl.accept_params do |p|
        p.namespace :nested do |f|
          f.float :badfloat, :required => true
        end
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::InvalidParamType)
    error.to_s.should =~ /\bbadfloat\b/

    error = nil
    ctrl = Controller.new(
      'nested' => {
        'twice' => {
          'badin' => 'purple',
        }
      }
    )
    begin
      ctrl.accept_params do |p|
        p.namespace :nested do |n|
          n.namespace :twice do |t|
            t.string :badin, :in => %w(red green blue)
          end
        end
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::InvalidParamValue)
    error.to_s.should =~ /\bbadin\b/

    error = nil
    ctrl = Controller.new(
      'username' => 'nate',
      'baby' => 'tuka',
    )
    begin
      ctrl.accept_params do |p|
        p.string :username, :required => true
      end
    rescue => error
    end
    error.should be_kind_of(AcceptParams::UnexpectedParam)
    error.to_s.should =~ /\bbaby\b/

    # ctrl.accept_params do |p|
    #   p.integer :id
    #   p.string :optional, :default => 42
    #   p.integer :optional2, :default => 43
    #   p.boolean :check
    #   p.boolean :check2, :default => false
    #   p.boolean :check3, :default => false
    #   p.string :color, :in => %w(red green blue)
    #   p.namespace :food do |f|
    #     f.integer :type_id, :in => 1..9
    #   end
    #   p.integer :page, :minvalue => 1
    #   p.integer :per_page, :required => true
    # end
    
  end
  
  
  
end