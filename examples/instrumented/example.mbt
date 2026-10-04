///|
#hotpath.measure("example")
pub fn example(x : Int) -> Int {
  // #hotpath.measure("inner")
  {
    let y = x + 1
    y
  }
}
