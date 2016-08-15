let debug = require('debug')('wson-diff:diff');

import StringDiff from './string-diff';
import ObjectDiff from './object-diff';
import ArrayDiff from './array-diff';

class State {

  constructor(differ) {
    this.differ = differ;
    this.wishStack = [];
    this.haveStack = [];
  }

  stringify(val, useHave) {
    let stack = useHave ? this.haveStack : this.wishStack;
    debug('stringify val=%o stack=%o', val, stack);
    return this.differ.wdiff.WSON.stringify(val, { haverefCb(backVal) {
      debug('stringify:   backVal=%o', backVal);
      for (let idx = 0; idx < stack.length; idx++) {
        let wish = stack[idx];
        debug('stringify:     wish=%o, idx=%o', wish, idx);
        if (wish === backVal) {
          debug('stringify:   found.');
          return stack.length - idx - 1;
        }
      }
      return null;
    }
  }
    );
  }

  getPlainDelta(have, wish, isRoot) {
    debug('getPlainDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot);
    let delta = this.stringify(wish);
    if (!isRoot) {
      delta = `:${delta}`;
    }
    return delta;
  }

  getStringDelta(have, wish, isRoot) {
    let diff = new StringDiff(this, have, wish);
    if (!diff.aborted) {
      var delta = diff.getDelta(isRoot);
    }
    if (diff.aborted) {
      var delta = this.getPlainDelta(have, wish, isRoot);
    }
    return delta;
  }

  getObjectDelta(have, wish, isRoot) {
    this.wishStack.push(wish);
    this.haveStack.push(have);
    let diff = new ObjectDiff(this, have, wish);
    if (!diff.aborted) {
      var delta = diff.getDelta(isRoot);
    }
    this.haveStack.pop();
    this.wishStack.pop();
    if (diff.aborted) {
      var delta = this.getPlainDelta(have, wish, isRoot);
    }
    return delta;
  }

  getArrayDelta(have, wish, isRoot) {
    this.wishStack.push(wish);
    this.haveStack.push(have);
    let diff = new ArrayDiff(this, have, wish);
    if (!diff.aborted) {
      var delta = diff.getDelta(isRoot);
    }
    this.haveStack.pop();
    this.wishStack.pop();
    if (diff.aborted) {
      var delta = this.getPlainDelta(have, wish, isRoot);
    }
    return delta;
  }

  getDelta(have, wish, isRoot) {
    let { WSON } = this.differ.wdiff;
    let haveTi = WSON.getTypeid(have);
    let wishTi = WSON.getTypeid(wish);
    if (wishTi !== haveTi) {
      return this.getPlainDelta(have, wish, isRoot);
    } else {
      switch (haveTi) {
        case 8: // Number
          if (have === wish || (have !== have && wish !== wish)) { // NaN
            return null;
          } else {
            return this.getPlainDelta(have, wish, isRoot);
          }
        case 16: // Date
          if (have.valueOf() === wish.valueOf()) {
            return null;
          } else {
            return this.getPlainDelta(have, wish, isRoot);
          }
        case 20: // String
          return this.getStringDelta(have, wish, isRoot);
        case 24: // Array
          return this.getArrayDelta(have, wish, isRoot);
        case 32: // Object
          return this.getObjectDelta(have, wish, isRoot);
        default:
          if (have === wish) {
            return null;
          } else {
            return this.getPlainDelta(have, wish, isRoot);
          }
      }
    }
  }
}


class Differ {

  constructor(wdiff, options) {
    this.wdiff = wdiff;
    let wdOptions = this.wdiff.options;
    if (!options) { options = {}; }
    this.stringEdge = (options.stringEdge != null) ?
      options.stringEdge
    : (wdOptions.stringEdge != null) ?
      wdOptions.stringEdge
    :
      16;
    this.stringLimit = (options.stringLimit != null) ?
      options.stringLimit
    :
      wdOptions.stringLimit;
    this.arrayLimit = (options.arrayLimit != null) ?
      options.arrayLimit
    :
      wdOptions.arrayLimit;
  }

  diff(src, dst) {
    let state = new State(this);
    return state.getDelta(src, dst, true);
  }
}


export { Differ };
