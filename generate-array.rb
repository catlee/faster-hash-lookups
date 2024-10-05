#!/usr/bin/env ruby
# frozen_string_literal: true
require "json"

# Generate N random string key/value pairs, and then write JSON out to stdout
# N is given as the first command line argument, and defaults to 100,000

num_pairs = ARGV[0]&.to_i || 100_000

data = num_pairs.times.map do
  [rand(36**8).to_s(36), rand(36**8).to_s(36)]
end.sort

puts JSON.generate(data)
