use capnp::serialize_packed;
use serde_json::from_str;
use std::io::Read;

mod array_capnp;

fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let mut buffer = String::new();
    std::io::stdin().read_to_string(&mut buffer)?;
    let json_entries = from_str::<Vec<(String, String)>>(&buffer)?;

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
    serialize_packed::write_message(&mut ::std::io::stdout(), &message)?;
    Ok(())
}
