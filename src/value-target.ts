import assert from 'assert';
import debugFactory from 'debug';
import { Wson } from 'wson';

import { NotifierTarget } from './notifier-target';
import { Key, Patch, Target } from './target';
import { AnyArray, AnyRecord, DiffConnector, Value } from './types';

const debug = debugFactory('wson-diff:value-target');

export class ValueTarget implements Target {
  public WSON: Wson;
  public root: Value;
  public current: Value;
  public stack: AnyRecord[];
  public topKey: Key;
  public subTarget: NotifierTarget | null;

  constructor(WSON: Wson, root: Value) {
    this.WSON = WSON;
    this.root = this.current = root;
    this.stack = [];
    this.topKey = null;
    this.subTarget = null;
  }

  public setSubTarget(subTarget: NotifierTarget | null): void {
    this.subTarget = subTarget;
  }

  public put_(key: Key, value: Value): void {
    if (key != null) {
      (this.current as AnyRecord)[key] = value;
    } else {
      this.current = value;
      const { stack } = this;
      if (stack.length === 0) {
        this.root = this.current;
      } else {
        assert(this.topKey != null);
        stack[stack.length - 1][this.topKey] = value;
      }
    }
  }

  public closeObjects_(tillIdx: number): void {
    let value = this.current as AnyRecord;
    const { stack } = this;
    let idx = stack.length;
    for (;;) {
      debug('closeObjects_ %o', value);
      if (typeof value === 'object' && value.constructor != null && value.constructor !== Object) {
        const connector = this.WSON.connectorOfValue(value);
        debug('closeObjects_ connector=%o', connector);
        if (connector) {
          const { postpatch } = connector as DiffConnector;
          if (postpatch) {
            postpatch(value);
          }
        }
      }
      if (--idx < tillIdx) {
        break;
      }
      value = stack[idx];
    }
  }

  public get(up: number): Value {
    if (up == null || up <= 0) {
      return this.current;
    } else {
      const { stack } = this;
      return stack[stack.length - up];
    }
  }

  public budge(up: number, key: Key): void {
    debug('budge(up=%o key=%o)', up, key);
    debug('budge: stack=%o current=%o', this.stack, this.current);
    const { stack } = this;
    let current: Value;
    if (this.subTarget) {
      this.subTarget.budge(up, key);
    }
    if (up > 0) {
      const newLen = stack.length - up;
      this.closeObjects_(newLen + 1);
      current = stack[newLen];
      stack.splice(newLen);
    } else {
      current = this.current;
    }
    if (key != null) {
      stack.push(current as AnyRecord);
      current = (current as AnyRecord)[key];
    }
    this.current = current;
    this.topKey = key;
  }

  public unset(key: string): void {
    debug('unset(key=%o) @current=%o', key, this.current);
    if (this.subTarget) {
      this.subTarget.unset(key);
    }
    delete (this.current as AnyRecord)[key];
  }

  public assign(key: Key, value: Value): void {
    debug('assign(key=%o value=%o)', key, value);
    if (this.subTarget) {
      this.subTarget.assign(key, value);
    }
    this.put_(key, value);
  }

  public delete(idx: number, len: number): void {
    debug('delete(idx=%o len=%o) @current=%o', idx, len, this.current);
    if (this.subTarget) {
      this.subTarget.delete(idx, len);
    }
    (this.current as AnyArray).splice(idx, len);
  }

  public move(srcIdx: number, dstIdx: number, len: number, reverse: boolean): void {
    debug('move(srcIdx=%o dstIdx=%o len=%o reverse=%o)', srcIdx, dstIdx, len, reverse);
    if (this.subTarget) {
      this.subTarget.move(srcIdx, dstIdx, len, reverse);
    }
    const current = this.current as AnyArray;
    const chunk = current.splice(srcIdx, len);
    if (reverse) {
      chunk.reverse();
    }
    current.splice(dstIdx, 0, ...chunk);
  }

  public insert(idx: number, values: AnyArray): void {
    if (this.subTarget) {
      this.subTarget.insert(idx, values);
    }
    const current = this.current as AnyArray;
    current.splice(idx, 0, ...values);
  }

  public replace(idx: number, values: AnyArray): void {
    debug('replace(idx=%o, values=%o)', idx, values);
    if (this.subTarget) {
      this.subTarget.replace(idx, values);
    }
    const valuesLen = values.length;
    if (valuesLen === 0) {
      return;
    }
    const current = this.current as AnyArray;
    let valuesIdx = 0;
    for (;;) {
      current[idx] = values[valuesIdx];
      if (++valuesIdx === valuesLen) {
        break;
      } else {
        ++idx;
      }
    }
  }

  public substitute(patches: Patch[]): void {
    debug('substitute(patches=%o)', patches);
    if (this.subTarget) {
      this.subTarget.substitute(patches);
    }
    const current = this.current as AnyArray;
    let result = '';
    let endOfs = 0;
    for (const patch of patches) {
      const [ofs, lenDiff, str] = patch;
      if (ofs > endOfs) {
        result += current.slice(endOfs, ofs);
      }
      const strLen = str.length;
      if (strLen > 0) {
        result += str;
      }
      endOfs = ofs + strLen - lenDiff;
      debug('substitute: patch=%o result=%o', patch, result);
    }
    if (current.length > endOfs) {
      result += current.slice(endOfs);
    }
    debug('substitute: result=%o', result);
    this.put_(null, result);
  }

  public done(): void {
    debug('done: stack=%o current=%o', this.stack, this.current);
    if (this.subTarget) {
      this.subTarget.done();
    }
    this.closeObjects_(0);
  }

  public getRoot(): Value {
    return this.root;
  }
}
