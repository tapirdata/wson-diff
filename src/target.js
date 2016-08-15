let debug = require('debug')('wson-diff:target');

class Target {

  get(up) {}
  budge(up, key) {}

  unset(key) {}
  assign(key, value) {}

  delete(idx, len) {}
  move(srcIdx, dstIdx, len, reverse) {}
  insert(idx, values) {}
  replace(idx, values) {}

  substitute(patches) {}
}


export default Target;
