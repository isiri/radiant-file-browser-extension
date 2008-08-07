unless defined? RADIANT_ROOT
  ENV["RAILS_ENV"] = "test"
  case
  when ENV["RADIANT_ENV_FILE"]
    require ENV["RADIANT_ENV_FILE"]
  when File.dirname(__FILE__) =~ %r{vendor/radiant/vendor/extensions}
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../../../")}/config/environment"
  else
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../")}/config/environment"
  end
end
require "#{RADIANT_ROOT}/spec/spec_helper"

if File.directory?(File.dirname(__FILE__) + "/scenarios")
  Scenario.load_paths.unshift File.dirname(__FILE__) + "/scenarios"
end
if File.directory?(File.dirname(__FILE__) + "/matchers")
  Dir[File.dirname(__FILE__) + "/matchers/*.rb"].each {|file| require file }
end

include ApplicationHelper
include DirectoryArray

Spec::Runner.configure do |config|
  # config.use_transactional_fixtures = true
  # config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/vendor/extensions/file_browser/spec/fixtures/'

  # You can declare fixtures for each behaviour like this:
  #   describe "...." do
  #     fixtures :table_a, :table_b
  #
  # Alternatively, if you prefer to declare them only once, you can
  # do so here, like so ...
  #
  #   config.global_fixtures = :table_a, :table_b
  #
  # If you declare global fixtures, be aware that they will be declared
  # for all of your examples, even those that don't use them.
end

######################
# Methods frequently used in the specs
######################
def create_dir(dirname, parent_id, version=current_version)
  post :new, :asset => {:name => dirname, :parent_id => parent_id, :new_type => 'Directory', :version => version}, :v => version
end

def create_file(filename, parent_id=nil)
  post :new, :asset => {:uploaded_data => fixture_file_upload(filename, "image/jpg"), :parent_id => parent_id, :new_type => 'File', :version => current_version}, :v => current_version
end

def error_message(err_type)
  [:modified, :unknown, :blankid].include?(err_type) ? Asset::Errors::CLIENT_ERRORS[err_type] : "Asset name " + Asset::Errors::CLIENT_ERRORS[err_type]
end

def current_version
  AssetLock.lock_version
end
