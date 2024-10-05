#!/usr/bin/env ruby
# frozen_string_literal: true
# Convert from JSON to various other formats / data structures
# Expects JSON array as input
# convert.rb -f <format> -s <structure> < input.json > output.<format>
# where format can be one of:
# - json
# - msgpack
# - pb (protobuf)
# - capnp (capnproto)
#
# and structure can be one of:
# - array
# - hash
# - chd (perfect hash encoded using CHD)
#
require "optparse"
require "json"

def transform_structure(data, target_structure)
  case target_structure
  when "array"
    data
  when "hash"
    data.to_h
  when "chd"
    require_relative "chd"
    data = data.to_h
    chd = CHDBuilder.new(data.keys, keys_per_bucket: 1)
    {
      "seeds" => chd.seeds,
      "m" => chd.m,
      "r" => chd.r,
      "data" => chd.transform_hash(data)
    }
  else
    raise "Unsupported structure: #{target_structure}"
  end
end

def encode_data(data, format)
  case format
  when "json"
    JSON.generate(data)
  when "msgpack"
    require "msgpack"
    MessagePack.pack(data)
  when "pb"
    encode_pb(data)
  when "capnp"
    encode_capnp(data)
  else
    raise "Unsupported format: #{format}"
  end
end

def encode_pb(data)
  if data.is_a?(Array)
    require_relative "proto/array_pb"
    pb_array = PBArray.new(entries: data.map { |k, v| Entry.new(key: k, value: v) })
    PBArray.encode(pb_array)
  elsif data.has_key?("seeds")
    require_relative "proto/chd_pb"
    pb_array = PBCHDHash.new(entries: data["data"].map { |k, v| Entry.new(key: k, value: v) }, seeds: data["seeds"], m: data["m"], r: data["r"])
    PBCHDHash.encode(pb_array)
  else
    require_relative "proto/hash_pb"
    pb_hash = PBHash.new(data:)
    PBHash.encode(pb_hash)
  end
end

def encode_capnp(data)
  require_relative "fhl"
  if data.is_a?(Array)
    FHL.json2capn_array(data)
  elsif data.has_key?("seeds")
    FHL.json2capn_chdhash(data)
  else
    # TODO
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("-f", "--format FORMAT", "Output format", ["json", "msgpack", "pb", "capnp"]) { |v| options[:format] = v }
  opts.on("-s", "--structure STRUCTURE", "Data structure", ["array", "hash", "chd"]) { |v| options[:structure] = v }
end.parse!

unless options[:format]
  STDERR.puts("Usage: convert.rb -f <format> -s <structure> < input.json > output.<format>")
  exit 1
end

data = JSON.parse(ARGF.read)

if options[:structure]
  unless data.is_a?(Array)
    STDERR.puts("Input data must be an array")
    exit 1
  end

  data = transform_structure(data, options[:structure])
end

STDOUT.write(encode_data(data, options[:format]))
