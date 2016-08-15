let debug = require('debug')('wson-diff:idxer');
import _ from 'lodash';

class Idxer {

  constructor(state, vals, useHave, allString) {
    this.state = state;
    if (allString) {
      for (var idx = 0; idx < vals.length; idx++) {
        var val = vals[idx];
        if (!_.isString(val)) {
          allString = false;
          break;
        }
      }
      var keys = vals;
    }
    if (!allString) {
      var keys = new Array(vals.length);
      for (var idx = 0; idx < vals.length; idx++) {
        var val = vals[idx];
        let key = this.state.stringify(val, useHave);
        keys[idx] = key;
      }
      debug('keys=%o', keys);  
    }
    this.keys = keys;
    this.allString = allString;
  }

  getItem(idx) {
    let key = this.keys[idx];
    if (this.allString) {
      return this.state.stringify(key);
    } else {
      return key;
    }
  }
}


export default Idxer;
