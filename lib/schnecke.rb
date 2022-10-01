# frozen_string_literal: true

require 'schnecke/version'
require File.join(File.dirname(__FILE__), 'schnecke', 'schnecke')

ActiveRecord::Base.instance_eval { include Schnecke }
if defined?(Rails) && Rails.version.to_i < 4
  raise 'This version of schnecke requires Rails 4 or higher'
end
