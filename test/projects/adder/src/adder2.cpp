#include "adder/adder.hpp"
#include "adder/adder2.hpp"

namespace adder {

int add_two(int x){
  return adder::add_one(adder::add_one(x));
}

} // namespace adder