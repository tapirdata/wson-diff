// tslint:disable:max-classes-per-file
import debugFactory from 'debug';

import { AnyArray, AnyRecord, Delta, Value } from './types';
import { DiffOptions } from './options';
import { ArrayDiff, ArrayLimiter } from './array-diff';
import { ObjectDiff } from './object-diff';
import { StringDiff, StringLimiter } from './string-diff';
import { WsonDiff } from './wson-diff';

const debug = debugFactory('wson-diff:diff');

export class State {
  public differ: Differ;
  public wishStack: AnyArray;
  public haveStack: AnyArray;

  constructor(differ: Differ) {
    this.differ = differ;
    this.wishStack = [];
    this.haveStack = [];
  }

  public stringify(val: Value, useHave = false): string {
    const stack = useHave ? this.haveStack : this.wishStack;
    debug('stringify val=%o stack=%o', val, stack);
    return this.differ.wdiff.WSON.stringify(val, {
      haverefCb(backVal: Value) {
        debug('stringify:   backVal=%o', backVal);
        for (let idx = 0; idx < stack.length; idx++) {
          const wish = stack[idx];
          debug('stringify:     wish=%o, idx=%o', wish, idx);
          if (wish === backVal) {
            debug('stringify:   found.');
            return stack.length - idx - 1;
          }
        }
        return null;
      },
    });
  }

  public getPlainDelta(have: Value, wish: Value, isRoot: boolean): string {
    debug('getPlainDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot);
    let delta = this.stringify(wish);
    if (!isRoot) {
      delta = `:${delta}`;
    }
    return delta;
  }

  public getStringDelta(have: string, wish: string, isRoot: boolean): Delta {
    const diff = new StringDiff(this, have, wish);
    let delta;
    if (diff.aborted) {
      delta = this.getPlainDelta(have, wish, isRoot);
    } else {
      delta = diff.getDelta(isRoot);
    }
    return delta;
  }

  public getObjectDelta(have: AnyRecord, wish: AnyRecord, isRoot: boolean): Delta {
    this.wishStack.push(wish);
    this.haveStack.push(have);
    const diff = new ObjectDiff(this, have, wish);
    let delta: Delta = null;
    if (!diff.aborted) {
      delta = diff.getDelta(isRoot);
    }
    this.haveStack.pop();
    this.wishStack.pop();
    if (diff.aborted) {
      delta = this.getPlainDelta(have, wish, isRoot);
    }
    return delta;
  }

  public getArrayDelta(have: AnyArray, wish: AnyArray, isRoot: boolean): Delta {
    this.wishStack.push(wish);
    this.haveStack.push(have);
    const diff = new ArrayDiff(this, have, wish);
    let delta = null;
    if (!diff.aborted) {
      delta = diff.getDelta(isRoot);
    }
    this.haveStack.pop();
    this.wishStack.pop();
    if (diff.aborted) {
      delta = this.getPlainDelta(have, wish, isRoot);
    }
    return delta;
  }

  public getDelta(have: Value, wish: Value, isRoot: boolean): Delta {
    const { WSON } = this.differ.wdiff;
    const haveTi = WSON.getTypeid(have);
    const wishTi = WSON.getTypeid(wish);
    if (wishTi !== haveTi) {
      return this.getPlainDelta(have, wish, isRoot);
    } else {
      switch (haveTi) {
        case 8: // Number
          if (have === wish || (have !== have && wish !== wish)) {
            // NaN
            return null;
          } else {
            return this.getPlainDelta(have, wish, isRoot);
          }
        case 16: // Date
          if ((have as Date).valueOf() === (wish as Date).valueOf()) {
            return null;
          } else {
            return this.getPlainDelta(have, wish, isRoot);
          }
        case 20: // String
          return this.getStringDelta(have as string, wish as string, isRoot);
        case 24: // Array
          return this.getArrayDelta(have as AnyArray, wish as AnyArray, isRoot);
        case 32: // Object
          return this.getObjectDelta(have as AnyRecord, wish as AnyRecord, isRoot);
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

export class Differ {
  public stringEdge: number;
  public stringLimit: number | StringLimiter | undefined;
  public arrayLimit: number | ArrayLimiter | undefined;

  constructor(public wdiff: WsonDiff, options: DiffOptions = {}) {
    const wdOptions = this.wdiff.options;
    this.stringEdge = options.stringEdge ?? wdOptions.stringEdge ?? 16;
    this.stringLimit = options.stringLimit ?? wdOptions.stringLimit;
    this.arrayLimit = options.arrayLimit ?? wdOptions.arrayLimit;
  }

  public diff(have: Value, wish: Value): Delta {
    const state = new State(this);
    return state.getDelta(have, wish, true);
  }
}
