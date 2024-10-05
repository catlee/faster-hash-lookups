# frozen_string_literal: true

require "rake/testtask"
require "rake/extensiontask"

Rake::ExtensionTask.new("fhl") do |c|
  c.lib_dir = "."
end

task :dev do
  ENV['RB_SYS_CARGO_PROFILE'] = 'dev'
end
