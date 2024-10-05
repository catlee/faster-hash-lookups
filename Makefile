.DELETE_ON_ERROR:

RUBY=bundle exec ruby -Iproto

DATA_STRUCTURES := array hash chd
OUTPUTS := $(addsuffix .json,$(DATA_STRUCTURES)) $(addsuffix .msgpack,$(DATA_STRUCTURES)) $(addsuffix .pb,$(DATA_STRUCTURES))
OUTPUTS := $(OUTPUTS) array.capnp chd.capnp

PB_FILES := $(wildcard definitions/*.proto)
PB_RUBY_FILES := $(PB_FILES:definitions/%.proto=proto/%_pb.rb)

CAPN_FILES := $(wildcard definitions/*.capnp)
CAPN_RUST_FILES := $(CAPN_FILES:definitions/%.capnp=ext/fhl/src/%_capnp.rs)

ALL: $(addprefix output/,$(OUTPUTS)) $(PB_RUBY_FILES) $(CAPN_RUST_FILES)

output/array.json: | output/
	$(RUBY) generate-array.rb > $@

output/hash.json: output/array.json
	$(RUBY) convert.rb -f json -s hash < $< > $@

output/chd.json: output/array.json
	$(RUBY) convert.rb -f json -s chd < $< > $@

output/array.pb : output/array.json proto/array_pb.rb
	$(RUBY) convert.rb -f pb -s array < $< > $@

output/hash.pb : output/array.json proto/hash_pb.rb
	$(RUBY) convert.rb -f pb -s hash < $< > $@

output/chd.pb : output/array.json proto/chd_pb.rb
	$(RUBY) convert.rb -f pb -s chd < $< > $@

output/array.capnp: output/array.json convert.rb
	$(RUBY) convert.rb -f capnp -s array < $< > $@

output/chd.capnp: output/array.json convert.rb
	$(RUBY) convert.rb -f capnp -s chd < $< > $@

%.msgpack: %.json
	$(RUBY) convert.rb -f msgpack < $< > $@

proto/%_pb.rb: definitions/%.proto
	protoc --ruby_out=proto -Idefinitions $<

ext/fhl/src/%_capnp.rs: definitions/%.capnp
	capnp compile -o rust:ext/fhl/src --src-prefix=definitions $<

output/:
	mkdir -p $@

convert.rb: fhl.so
	touch $@

fhl.so: ext/fhl/extconf.rb ext/fhl/src/lib.rs $(CAPN_RUST_FILES)
	bundle exec rake compile

clean:
	rm -rf output/*
