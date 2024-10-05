#!/usr/bin/env ruby
# frozen_string_literal: true
require "benchmark/ips"
require "json"

data = JSON.parse(ARGF.read)

Benchmark.ips do |x|
  x.report("to_h") { data.to_h }
end
