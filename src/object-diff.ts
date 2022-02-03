import _ from 'lodash';
import debugFactory from 'debug';

import { State } from './diff';
import { AnyRecord, Delta } from './types';
import { Connector } from 'wson';

const debug = debugFactory('wson-diff:object-diff');

interface DiffConnector extends Connector {
  diffKeys?: string[];
}

export class ObjectDiff {
  public aborted: boolean;

  constructor(public state: State, public have: AnyRecord, public wish: AnyRecord) {
    this.aborted = have.constructor !== wish.constructor;
  }

  public getDelta(isRoot: boolean): Delta {
    const { have } = this;
    const { wish } = this;
    debug('getDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot);
    let delta = '';
    const { state } = this;

    let diffKeys: string[] | null = null;
    if (have.constructor != null && have.constructor !== Object) {
      const connector = state.differ.wdiff.WSON.connectorOfValue(have);
      diffKeys = connector ? (connector as DiffConnector).diffKeys ?? null : null;
      console.log('diffKeys=', diffKeys, 'connector=', connector);
    }

    let delCount = 0;
    const haveKeys: string[] = diffKeys ?? _(have).keys().sort().value();
    for (const key of haveKeys) {
      if (!_.has(wish, key)) {
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
    const wishKeys: string[] = diffKeys ?? _(wish).keys().sort().value();
    for (const key of wishKeys) {
      if (diffKeys && !_.has(wish, key)) {
        continue;
      }
      const keyDelta = state.getDelta(have[key], wish[key], false);
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
