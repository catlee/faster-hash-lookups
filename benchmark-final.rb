#!/usr/bin/env ruby
# frozen_string_literal: true
require "optparse"
require "json"
require "benchmark/ips"
require "msgpack"

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

def parse_msgpack(data, structure)
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

def load(format, structure)
  File.read("output/#{structure}.#{format}")
end

data = load("json", "array")
obj = parse_json(data, "array")
needle = obj.last[0]
value = get_key_array(obj, needle, "json")

Benchmark.ips do |x|
  ["array", "hash", "chd"].each do |structure|
    ["json", "msgpack", "pb"].each do |format|
      parse_method = method("parse_#{format}".to_sym)
      get_key_method = method("get_key_#{structure}".to_sym)
      if (v = get_key_method.call(parse_method.call(load(format, structure), structure), needle, format)) != value
        raise "Mismatch for key #{needle}: expected #{value}, for #{format} #{structure}; got #{v}"
      end
      x.report("load/parse/get_key #{format} #{structure}") do
        data = load(format, structure)
        obj = parse_method.call(data, structure)
        v = get_key_method.call(obj, needle, format)
        raise "Mismatch for key #{needle}: expected #{value}, for #{format} #{structure}; got #{v}" if v != value
      end
    end
  end
  x.compare!
end
