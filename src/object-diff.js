import _ from 'lodash';
let debug = require('debug')('wson-diff:object-diff');


let { hasOwnProperty } = Object.prototype;

class ObjectDiff {

  constructor(state, have, wish) {
    this.state = state;
    if (have.constructor !== wish.constructor) {
      this.aborted = true;
    } else {
      this.have = have;
      this.wish = wish;
      this.aborted = false;
    }
  }


  getDelta(isRoot) {
    let { have } = this;
    let { wish } = this;
    debug('getDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot);
    let delta = '';
    let { state } = this;

    let diffKeys = null;
    if ((have.constructor != null) && have.constructor !== Object) {
      let connector = state.differ.wdiff.WSON.connectorOfValue(have);
      diffKeys = connector ? connector.diffKeys : null;
    }
    let hasDiffKeys = (diffKeys != null);

    let delCount = 0;
    let haveKeys = hasDiffKeys ? diffKeys : _(have).keys().sort().value();
    for (let i = 0; i < haveKeys.length; i++) {
      var key = haveKeys[i];
      if (!hasOwnProperty.call(wish, key)) {
        if (delCount === 0) {
          if (isRoot) {
            delta += '|';
          }
          delta += '[-';
        } else {
          delta += '|';
        }
        delta += state.stringify(key);
        ++delCount;
      }
    }
    if (delCount > 0) {
      delta += ']';
    }

    let setDelta = '';
    let setCount = 0;
    let wishKeys = hasDiffKeys ? diffKeys : _(wish).keys().sort().value();
    for (let j = 0; j < wishKeys.length; j++) {
      var key = wishKeys[j];
      if (hasDiffKeys && !hasOwnProperty.call(wish, key)) {
        continue;
      }
      let keyDelta = state.getDelta(have[key], wish[key]);
      debug('getDelta: key=%o, keyDelta=%o', key, keyDelta);
      if (keyDelta != null) {
        if (setCount > 0) {
          setDelta += '|';
        }
        setDelta += state.stringify(key) + keyDelta;
        ++setCount;
      }
    }
    debug('getDelta: setDelta=%o, setCount=%o', setDelta, setCount);
    if (setCount > 0) {
      if (isRoot) {
        if (delCount === 0) {
          delta += '|';
        }
        delta += setDelta;
      } else {
        if (setCount === 1 && delCount === 0) {
          delta += '|';
          delta += setDelta;
        } else {
          delta += `[=${setDelta}]`;
        }
      }
    }
    if (delta.length) {
      return delta;
    } else {
      return null;
    }
  }
}



export default ObjectDiff;

