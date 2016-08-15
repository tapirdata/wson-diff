import _ from 'lodash';
let debug = require('debug')('wson-diff:string-diff');

import mdiff from 'mdiff';


class StringDiff {

  constructor(state, have, wish) {
    this.state = state;
    let patches = [];
    if (have === wish) {
      this.aborted = false;
    } else {
      let edge = this.state.differ.stringEdge;
      if (wish.length < edge) {
        this.aborted = true;
        return;
      }
      let sd = this;
      let scanCb = function(haveBegin, haveEnd, wishBegin, wishEnd) {
        debug('scan: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd);
        return patches.push([haveBegin, haveEnd - haveBegin, wish.slice(wishBegin, wishEnd)]);
      };

      let limit = this.state.differ.stringLimit;
      if (_.isFunction(limit)) {
        limit = limit(have(wish));
      }
      let diffLen = mdiff(have, wish).scanDiff(scanCb, limit);
      this.aborted = (diffLen == null);
    }
    this.patches = patches;
  }


  getDelta(isRoot) {
    let { patches } = this;
    if (patches.length === 0) {
      return null;
    }
    let { WSON } = this.state.differ.wdiff;
    let delta = isRoot ? '|[s' : '[s';
    for (let patchIdx = 0; patchIdx < patches.length; patchIdx++) {
      let patch = patches[patchIdx];
      let [ofs, len, str] = patch;
      if (patchIdx > 0) {
        delta += '|';
      }
      delta += ofs;
      let strLen = str.length;
      if (len > strLen) {
        delta += `-${len - strLen}`;
      } else if (len < strLen) {
        delta += `+${strLen - len}`;
      }
      if (str.length > 0) {
        delta += `=${WSON.escape(str)}`;
      }
    }
    delta += ']';
    return delta;
  }
}


export default StringDiff;

