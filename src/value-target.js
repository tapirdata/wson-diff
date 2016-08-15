let debug = require('debug')('wson-diff:value-target');

import Target from './target';

class ValueTarget extends Target {

  constructor(WSON, root) {
    super()
    this.WSON = WSON;
    this.root = this.current = root;
    this.stack = [];
    this.topKey = null;
    this.subTarget = null;
  }

  setSubTarget(subTarget) {
    this.subTarget = subTarget;
  }

  put_(key, value) {
    if (key != null) {
      this.current[key] = value;
    } else {
      this.current = value;
      let { stack } = this;
      if (stack.length === 0) {
        this.root = this.current;
      } else {
        stack[stack.length - 1][this.topKey] = value;
      }
    }
  }

  closeObjects_(tillIdx) {
    let value = this.current;
    let { stack } = this;
    let idx = stack.length;
    while (true) {
      debug('closeObjects_ %o', value);
      if (typeof value === 'object' && (value.constructor != null) && value.constructor !== Object) {
        let connector = this.WSON.connectorOfValue(value);
        debug('closeObjects_ connector=%o', connector);
        if (connector && connector.postpatch) {
          connector.postpatch.call(value);
        }
      }
      if (--idx < tillIdx) {
        break;
      }
      value = stack[idx];
    }
  }

  get(up) {
    if ((up == null) || up <= 0) {
      return this.current;
    } else {
      let { stack } = this;
      return stack[stack.length - up];
    }
  }

  budge(up, key) {
    debug('budge(up=%o key=%o)', up, key);
    debug('budge: stack=%o current=%o', this.stack, this.current);
    let { stack } = this;
    if (this.subTarget) {
      this.subTarget.budge(up, key);
    }
    if (up > 0) {
      let newLen = stack.length - up;
      this.closeObjects_(newLen + 1);
      var current = stack[newLen];
      stack.splice(newLen);
    } else {
      var { current } = this;
    }
    if (key != null) {
      stack.push(current);
      var current = current[key];
    }
    this.current = current;
    this.topKey = key;
  }

  unset(key) {
    debug('unset(key=%o) @current=%o', key, this.current);
    if (this.subTarget) {
      this.subTarget.unset(key);
    }
    delete this.current[key];
  }

  assign(key, value) {
    debug('assign(key=%o value=%o)', key, value);
    if (this.subTarget) {
      this.subTarget.assign(key, value);
    }
    this.put_(key, value);
  }

  delete(idx, len) {
    debug('delete(idx=%o len=%o) @current=%o', idx, len, this.current);
    if (this.subTarget) {
      this.subTarget.delete(idx, len);
    }
    this.current.splice(idx, len);
  }

  move(srcIdx, dstIdx, len, reverse) {
    debug('move(srcIdx=%o dstIdx=%o len=%o reverse=%o)', srcIdx, dstIdx, len, reverse);
    if (this.subTarget) {
      this.subTarget.move(srcIdx, dstIdx, len, reverse);
    }
    let { current } = this;
    let chunk = current.splice(srcIdx, len);
    if (reverse) {
      chunk.reverse();
    }
    current.splice.apply(current, [dstIdx, 0].concat(chunk));
  }

  insert(idx, values) {
    if (this.subTarget) {
      this.subTarget.insert(idx, values);
    }
    let { current } = this;
    current.splice.apply(current, [idx, 0].concat(values));
  }

  replace(idx, values) {
    debug('replace(idx=%o, values=%o)', idx, values);
    if (this.subTarget) {
      this.subTarget.replace(idx, values);
    }
    let valuesLen = values.length;
    if (valuesLen === 0) {
      return;
    }
    let { current } = this;
    let valuesIdx = 0;
    while (true) {
      current[idx] = values[valuesIdx];
      if (++valuesIdx === valuesLen) {
        break;
      } else {
        ++idx;
      }
    }
  }

  substitute(patches) {
    debug('substitute(patches=%o)', patches);
    if (this.subTarget) {
      this.subTarget.substitute(patches);
    }
    let { current } = this;
    let result = '';
    let endOfs = 0;
    for (let i = 0; i < patches.length; i++) {
      let patch = patches[i];
      let [ofs, lenDiff, str] = patch;
      if (ofs > endOfs) {
        result += current.slice(endOfs, ofs);
      }
      let strLen = str.length;
      if (strLen > 0) {
        result += str;
      }
      endOfs = (ofs + strLen) - lenDiff;
      debug('substitute: patch=%o result=%o', patch, result);
    }
    if (current.length > endOfs) {
      result += current.slice(endOfs);
    }
    debug('substitute: result=%o', result);
    this.put_(null, result);
  }

  done() {
    debug('done: stack=%o current=%o', this.stack, this.current);
    if (this.subTarget) {
      this.subTarget.done();
    }
    this.closeObjects_(0);
  }

  getRoot() { return this.root; }
}


export default ValueTarget;

