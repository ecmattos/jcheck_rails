$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'jcheck_rails'
require 'rspec'

RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
end

require 'active_model'

def jcheck(*args)
  JcheckRails.jcheck_for(*args)
end

def mock_model(&block)
  cls = Class.new
  cls.send :include, ActiveModel::Validations
  cls.class_eval &block
  cls.new
end
