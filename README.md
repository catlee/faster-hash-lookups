# Efficient Hash Lookups: Adventures with Benchmarks!

This repository contains code that goes along with my blog post [here](https://atlee.ca/posts/faster-hash-lookups/)

# Usage

It assumes you have a relatively recent ruby installed.
It also contains experimental capnproto code, which may or not work properly :)

```console
$ bundle install
# Generate all sample data
$ make

# Benchmark JSON hash, using output/hash.json
$ bundle exec ruby benchmark.rb -s hash -f json
```



