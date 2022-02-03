import * as _ from 'lodash';
import debugFactory from 'debug';
import mdiff from 'mdiff';

import { State } from './diff';
import { Delta } from './types';

const debug = debugFactory('wson-diff:string-diff');

export type Patch = [number, number, string];
export type StringLimiter = (have: string, wish: string) => number;

export class StringDiff {
  public state: State;
  public aborted: boolean;
  public patches: Patch[] = [];

  constructor(state: State, have: string, wish: string) {
    function scanCb(haveBegin: number, haveEnd: number, wishBegin: number, wishEnd: number) {
      debug('scan: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd);
      patches.push([haveBegin, haveEnd - haveBegin, wish.slice(wishBegin, wishEnd)]);
    }

    this.state = state;
    const patches: Patch[] = [];
    if (have === wish) {
      this.aborted = false;
    } else {
      const edge = this.state.differ.stringEdge;
      if (wish.length < edge) {
        this.aborted = true;
        return;
      }
      let limit = this.state.differ.stringLimit;
      if (_.isFunction(limit)) {
        limit = (limit as (have: string, wish: string) => number)(have, wish);
      }
      const diffLen = mdiff(have, wish).scanDiff(scanCb, limit);
      this.aborted = diffLen == null;
    }
    this.patches = patches;
  }

  public getDelta(isRoot: boolean): Delta {
    const { patches } = this;
    if (patches.length === 0) {
      return null;
    }
    const { WSON } = this.state.differ.wdiff;
    let delta = isRoot ? '|[s' : '[s';
    for (let patchIdx = 0; patchIdx < patches.length; patchIdx++) {
      const patch = patches[patchIdx];
      const [ofs, len, str] = patch;
      if (patchIdx > 0) {
        delta += '|';
      }
      delta += ofs;
      const strLen = str.length;
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
