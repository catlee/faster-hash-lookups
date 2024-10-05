#!/usr/bin/env ruby
# frozen_string_literal: true
# Runs benchmarks for loading / parsing / extracting keys from different file formats and data structures
# benchmark.rb -f <format> -s <structure>
# where format can be one of:
# - json
# - msgpack
# - pb (protobuf)
#
# and structure can be one of:
# - array
# - hash
# - chd (perfect hash encoded using CHD)
#
require "optparse"
require "json"
require "benchmark/ips"
require "msgpack"
require "debug"

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "proto")))
require_relative "chd"
require_relative "proto/chd_pb"
require_relative "proto/array_pb"
require_relative "proto/hash_pb"

def parse_json(data, structure)
  data = JSON.parse(data)
  case structure
  when "chd"
    params = CHDParams.new(data["seeds"], data["m"], data["r"])
    CHDHash.new(data["data"], params)
  else
    data
  end
end

def parse_msgpack(data, _structure)
  data = MessagePack.unpack(data)
  case structure
  when "chd"
    params = CHDParams.new(data["seeds"], data["m"], data["r"])
    CHDHash.new(data["data"], params)
  else
    data
  end
end

def parse_pb(data, structure)
  case structure
  when "array"
    PBArray.decode(data).entries
  when "hash"
    PBHash.decode(data).data
  when "chd"
    data = PBCHDHash.decode(data)
    params = CHDParams.new(data.seeds, data.m, data.r)
    CHDHash.new(data.entries, params)
  end
end

def load(format, structure)
  File.read("output/#{structure}.#{format}")
end

def get_key_array(obj, needle, format)
  if format == "pb"
    obj.bsearch { |e| needle <=> e.key }.value
  else
    obj.bsearch { |k, v| needle <=> k }.last
  end
end

def get_key_hash(obj, needle, _format)
  obj[needle]
end

def get_key_chd(obj, needle, _format)
  obj[needle]
end

options = {}
OptionParser.new do |opts|
  opts.on("-f", "--format FORMAT", "Output format", ["json", "msgpack", "pb"]) { |v| options[:format] = v }
  opts.on("-s", "--structure STRUCTURE", "Data structure", ["array", "hash", "chd"]) { |v| options[:structure] = v }
end.parse!

unless options[:format] && options[:structure]
  STDERR.puts("Usage: convert.rb -f <format> -s <structure> < input")
  exit 1
end

unless parse_method = method("parse_#{options[:format]}".to_sym)
  STDERR.puts "Don't know how to parse #{options[:format]}"
  exit 1
end

unless get_key_method = method("get_key_#{options[:structure]}".to_sym)
  STDERR.puts "Don't know how to get_key for #{options[:structure]}"
  exit 1
end

ORIG_DATA = parse_json(load("json", "hash"), "hash")
DATA = load(options[:format], options[:structure])
OBJ = parse_method.call(DATA, options[:structure])

needle = ORIG_DATA.keys.last
value = ORIG_DATA[needle]

# Sanity check
if get_key_method.call(OBJ, needle, options[:format]) != value
  raise "Mismatch for key #{needle}: expected #{value}, got #{get_key_method.call(OBJ, needle, options[:format])}"
end

Benchmark.ips do |x|
  x.report("load") { load(options[:format], options[:structure]) }
  x.report("parse") { parse_method.call(DATA, options[:structure]) }
  x.report("get_key") do 
    v = get_key_method.call(OBJ, needle, options[:format])
    raise "Mismatch for key #{needle}: expected #{value}, got #{v}" if v != value
  end
  # x.report("get a key") do
  #   OBJ[rand(OBJ.size)].key
  # end
  # x.report("parse/get a key") do
  #   obj = parse_method.call(DATA, options[:structure])
  #   obj[obj.size/2]
  # end
  x.report("parse/get_key") do
    obj = parse_method.call(DATA, options[:structure])
    v = get_key_method.call(obj, needle, options[:format])
    raise "Mismatch for key #{needle}: expected #{value}, got #{v}" if v != value
  end
  x.report("load/parse/get_key") do
    data = load(options[:format], options[:structure])
    obj = parse_method.call(data, options[:structure])
    v = get_key_method.call(obj, needle, options[:format])
    raise "Mismatch for key #{needle}: expected #{value}, got #{v}" if v != value
  end
end
