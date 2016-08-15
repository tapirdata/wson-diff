import _ from 'lodash';
let debug = require('debug')('wson-diff:patch');
import wson from 'wson';

import * as patch from './patch';
import * as diff from './diff';

class WsonDiff {

  constructor(options) {
    if (!options) { options = {}; }
    let { WSON } = options;
    if (WSON == null) {
      WSON = wson(options.wsonOptions);
    }
    this.WSON = WSON;
    this.options = options;
  }

  createPatcher(options) {
    if (!options) { options = {}; }
    return new patch.Patcher(this, options);
  }

  createDiffer(options) {
    if (!options) { options = {}; }
    return new diff.Differ(this, options);
  }

  diff(have, wish, options) {
    let differ = this.createDiffer(options);
    return differ.diff(have, wish);
  }

  patch(have, delta, options) {
    let patcher = this.createPatcher(options);
    return patcher.patch(have, delta, __guard__(options, x => x.notifiers));
  }

  patchTarget(target, delta, options) {
    let patcher = this.createPatcher(options);
    return patcher.patchTarget(target, delta);
  }
}



let factory = options => new WsonDiff(options);

factory.PatchError = patch.PatchError;

export default factory;










function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}
