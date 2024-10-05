#!/usr/bin/env ruby
# frozen_string
# Based on https://gist.github.com/pervognsen/b21f6dd13f4bcb4ff2123f0d78fcfd17

require "forwardable"
require "set"
require "cityhash"

def cityhash(seed, key, modulo)
  CityHash.hash64(key, seed) % modulo
end

CHDParams = Struct.new(:seeds, :m, :r)

class CHDBuilder
  attr_reader :seeds, :m, :r, :rhash

  def initialize(keys, load_factor:1.0, keys_per_bucket:4, rhash:method(:cityhash), max_seed:1_000_000)
    @rhash = rhash
    @m = (keys.size / load_factor).floor
    @r = (keys.size / keys_per_bucket).floor
    @seeds = [0] * @r
    @keys = keys
    @max_seed = max_seed

    generate_seeds
  end

  def transform_hash(data)
    # Output data as an array of key/value pairs in the order determined by the hash function
    output = Array.new(@m)
    data.each do |k, v|
      idx = rhash.call(seeds[rhash.call(0, k, r)], k, m)
      if output[idx]
        raise "Collision detected at index #{idx} for key #{k}"
      end
      output[idx] = [k, v]
    end
    output
  end

  private

  def generate_seeds
    buckets = @r.times.map { [] }
    @keys.each { |k| buckets[rhash.call(0, k, @r)] << k }
    occupied = Set[]
    buckets.each_with_index.sort_by { |bucket, i| -bucket.size } .each do |bucket, i|
      @max_seed.times do |seed|
        bucket_occupied = Set[]
        collision = false
        bucket.each do |k|
          h = rhash.call(seed, k, @m)
          if occupied.include?(h) || bucket_occupied.include?(h)
            collision = true
            break
          else
            bucket_occupied << h
          end
        end
        unless collision
          occupied.merge(bucket_occupied)
          @seeds[i] = seed
          break
        end
      end
    end
  end
end

class CHDHash
  attr_reader :data
  attr_reader :seeds

  def initialize(data, params, rhash:method(:cityhash))
    # We expect data to a be an array of key/value pairs
    @data = data

    @rhash = rhash

    @m = params.m
    @r = params.r
    @seeds = params.seeds
  end

  def size
    @data.size
  end

  def [](key)
    idx = @rhash.call(@seeds[@rhash.call(0, key, @r)], key, @m)
    e = @data[idx]
    if e.respond_to?(:key)
      return e.value if e.key == key
    else
      k, v = e
      return v if k == key
    end
    nil
  end

  def fetch(key, default=NO_DEFAULT, &block)
    idx = @rhash.call(@seeds[@rhash.call(0, key, @r)], key, @m)
    k, v = @data[idx]
    return v if k == key
    return default if default != NO_DEFAULT
    return block.call(key) if block
    raise KeyError, "key not found: #{key}"
  end

  private

  NO_DEFAULT = Object.new
end
