@0xfb9002e96408d8aa;

struct CapnEntry {
  key @0 :Text;
  value @1 :Text;
}

struct CapnArray {
  entries @0 :List(CapnEntry);
}
