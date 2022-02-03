import * as _ from 'lodash';
import debugFactory from 'debug';
import wsonFactory, { Wson } from 'wson';

import { Delta, Value } from './types';
import { Differ } from './diff';
import { Patcher } from './patch';
import { Target } from './target';
import { DiffOptions, PatchOptions } from './options';

const _debug = debugFactory('wson-diff:wson-diff');

export class WsonDiff {
  public WSON: Wson;

  constructor(public options: DiffOptions = {}) {
    let { WSON } = options;
    if (WSON == null) {
      WSON = wsonFactory(options.wsonOptions);
    }
    this.WSON = WSON;
  }

  public createPatcher(options: PatchOptions = {}): Patcher {
    return new Patcher(this, options);
  }

  public createDiffer(options: DiffOptions = {}): Differ {
    return new Differ(this, options);
  }

  public diff(have: Value, wish: Value, options: DiffOptions = {}): Delta {
    const differ = this.createDiffer(options);
    return differ.diff(have, wish);
  }

  public patch(have: Value, delta: Delta, options: DiffOptions = {}): Value {
    const patcher = this.createPatcher(options);
    return patcher.patch(have, delta, options ? options.notifiers : undefined);
  }

  public patchTarget(target: Target, delta: Delta, options: PatchOptions = {}): Value {
    const patcher = this.createPatcher(options);
    return patcher.patchTarget(target, delta);
  }
}
