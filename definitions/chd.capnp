@0xc78000dd8c559ce1;

struct CapnEntry {
  key @0 :Text;
  value @1 :Text;
}

struct CapnChdHash {
  entries @0 :List(CapnEntry);
  seeds @1 :List(Int32);
  m @2 :Int32;
  r @3 :Int32;
}
