use magnus::Module;
use magnus::Object;
use magnus::RHash;
use magnus::TryConvert;
use magnus::Value;
use magnus::{function, method, Error, RString, Ruby};

mod array_capnp;
mod chd_capnp;

#[magnus::wrap(class = "FHL::CapnArray")]
struct CapnArray {
    reader: ::capnp::message::Reader<capnp::serialize::OwnedSegments>,
}

impl CapnArray {
    fn new(ruby: &Ruby, data: RString) -> Result<Self, Error> {
        let message_reader = unsafe {
            capnp::serialize_packed::read_message(
                data.as_slice(),
                ::capnp::message::ReaderOptions::new(),
            )
        }
        .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;

        Ok(CapnArray {
            reader: message_reader,
        })
    }

    fn size(ruby: &Ruby, rb_self: &Self) -> Result<u32, Error> {
        let root = rb_self
            .reader
            .get_root::<array_capnp::capn_array::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        Ok(root
            .get_entries()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
            .len())
    }

    fn get(ruby: &Ruby, rb_self: &Self, index: u32) -> Result<(String, String), Error> {
        let root = rb_self
            .reader
            .get_root::<array_capnp::capn_array::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        let entry = root
            .get_entries()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
            .get(index);
        Ok((
            entry
                .get_key()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
                .to_string()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?,
            entry
                .get_value()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
                .to_string()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?,
        ))
    }
}

fn json2capn_array(ruby: &Ruby, json_entries: Vec<(String, String)>) -> Result<RString, Error> {
    let mut message = ::capnp::message::Builder::new_default();
    {
        let array = message.init_root::<array_capnp::capn_array::Builder>();
        let mut capn_entries = array.init_entries(json_entries.len() as u32);
        json_entries.iter().enumerate().for_each(|(i, entry)| {
            let mut e = capn_entries.reborrow().get(i as u32);
            e.set_key(entry.0.clone());
            e.set_value(entry.1.clone());
        });
    }

    let mut output = vec![];
    capnp::serialize_packed::write_message(&mut output, &message)
        .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
    Ok(ruby.str_from_slice(&output))
}

#[derive(serde::Serialize, serde::Deserialize)]
struct CHDHash {
    entries: Vec<(String, String)>,
    seeds: Vec<i32>,
    m: i32,
    r: i32,
}

impl TryConvert for CHDHash {
    fn try_convert(value: Value) -> Result<Self, Error> {
        let hash = RHash::from_value(value).unwrap();
        Ok(CHDHash {
            entries: Vec::<(String, String)>::try_convert(hash.get("data").unwrap()).unwrap(),
            seeds: Vec::<i32>::try_convert(hash.get("seeds").unwrap()).unwrap(),
            m: i32::try_convert(hash.get("m").unwrap()).unwrap(),
            r: i32::try_convert(hash.get("r").unwrap()).unwrap(),
        })
    }
}

fn json2capn_chdhash(ruby: &Ruby, chd_hash: CHDHash) -> Result<RString, Error> {
    let mut message = ::capnp::message::Builder::new_default();
    {
        let mut array = message.init_root::<chd_capnp::capn_chd_hash::Builder>();
        let mut capn_entries = array.reborrow().init_entries(chd_hash.entries.len() as u32);
        chd_hash.entries.iter().enumerate().for_each(|(i, entry)| {
            let mut e = capn_entries.reborrow().get(i as u32);
            e.set_key(entry.0.clone());
            e.set_value(entry.1.clone());
        });
        let mut capn_seeds = array.reborrow().init_seeds(chd_hash.seeds.len() as u32);
        chd_hash.seeds.iter().enumerate().for_each(|(i, seed)| {
            capn_seeds.set(i as u32, *seed);
        });

        array.set_m(chd_hash.m);
        array.set_r(chd_hash.r);
    }

    let mut output = vec![];
    capnp::serialize_packed::write_message(&mut output, &message)
        .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
    Ok(ruby.str_from_slice(&output))
}

#[magnus::wrap(class = "FHL::CapnCHDHash")]
struct CapnCHDHash {
    reader: ::capnp::message::Reader<capnp::serialize::OwnedSegments>,
}

impl CapnCHDHash {
    fn new(ruby: &Ruby, data: RString) -> Result<Self, Error> {
        let message_reader = unsafe {
            capnp::serialize_packed::read_message(
                data.as_slice(),
                *::capnp::message::ReaderOptions::new().traversal_limit_in_words(None),
            )
        }
        .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;

        Ok(CapnCHDHash {
            reader: message_reader,
        })
    }

    fn size(ruby: &Ruby, rb_self: &Self) -> Result<u32, Error> {
        let root = rb_self
            .reader
            .get_root::<chd_capnp::capn_chd_hash::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        Ok(root
            .get_entries()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
            .len())
    }

    fn entry(ruby: &Ruby, rb_self: &Self, index: u32) -> Result<(String, String), Error> {
        let root = rb_self
            .reader
            .get_root::<chd_capnp::capn_chd_hash::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        let entry = root
            .get_entries()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
            .get(index);
        Ok((
            entry
                .get_key()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
                .to_string()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?,
            entry
                .get_value()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
                .to_string()
                .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?,
        ))
    }

    fn seed(ruby: &Ruby, rb_self: &Self, index: u32) -> Result<i32, Error> {
        let root = rb_self
            .reader
            .get_root::<chd_capnp::capn_chd_hash::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        let seed = root
            .get_seeds()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?
            .get(index);
        Ok(seed)
    }

    fn m(ruby: &Ruby, rb_self: &Self) -> Result<i32, Error> {
        let root = rb_self
            .reader
            .get_root::<chd_capnp::capn_chd_hash::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        Ok(root.get_m())
    }

    fn r(ruby: &Ruby, rb_self: &Self) -> Result<i32, Error> {
        let root = rb_self
            .reader
            .get_root::<chd_capnp::capn_chd_hash::Reader>()
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;
        Ok(root.get_r())
    }
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("FHL")?;
    module.define_module_function("json2capn_array", function!(json2capn_array, 1))?;
    module.define_module_function("json2capn_chdhash", function!(json2capn_chdhash, 1))?;
    let class = module.define_class("CapnArray", ruby.class_object())?;
    class.define_singleton_method("new", function!(CapnArray::new, 1))?;
    class.define_method("size", method!(CapnArray::size, 0))?;
    class.define_method("[]", method!(CapnArray::get, 1))?;

    let class = module.define_class("CapnCHDHash", ruby.class_object())?;
    class.define_singleton_method("new", function!(CapnCHDHash::new, 1))?;
    class.define_method("size", method!(CapnCHDHash::size, 0))?;
    class.define_method("seed", method!(CapnCHDHash::seed, 1))?;
    class.define_method("entry", method!(CapnCHDHash::entry, 1))?;
    class.define_method("m", method!(CapnCHDHash::m, 0))?;
    class.define_method("r", method!(CapnCHDHash::r, 0))?;
    Ok(())
}
