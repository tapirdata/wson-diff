import _ from 'lodash';
let debug = require('debug')('wson-diff:patch');
import wson from 'wson';

import * as patch from './patch';
import * as diff from './diff';

class WsonDiff {

  constructor(options = {}) {
    let { WSON } = options;
    if (WSON == null) {
      WSON = wson(options.wsonOptions);
    }
    this.WSON = WSON;
    this.options = options;
  }

  createPatcher(options = {}) {
    return new patch.Patcher(this, options);
  }

  createDiffer(options = {}) {
    return new diff.Differ(this, options);
  }

  diff(have, wish, options) {
    let differ = this.createDiffer(options);
    return differ.diff(have, wish);
  }

  patch(have, delta, options) {
    let patcher = this.createPatcher(options);
    return patcher.patch(have, delta, options ? options.notifiers : undefined);
  }

  patchTarget(target, delta, options) {
    let patcher = this.createPatcher(options);
    return patcher.patchTarget(target, delta);
  }
}



let factory = options => new WsonDiff(options);

factory.PatchError = patch.PatchError;

export default factory;


