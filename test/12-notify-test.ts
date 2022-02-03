import * as _ from 'lodash';
import { expect } from 'chai';
import debugFactory = require('debug');

import wdiffFactory, { Key, Notifier, Patch } from '../src';
import { safeRepr } from './fixtures/helpers';
import { items } from './fixtures/notify-items';
import { setups } from './fixtures/setups';
import { AnyArray, Value } from '../src/types';

const debug = debugFactory('wson-diff:test');

class MyNotifier implements Notifier {
  public budgeTest: (...args: AnyArray) => boolean;
  public nfys: unknown[][];
  public keyStack: Key[];

  constructor(budgeTest: (top: Value) => boolean) {
    this.budgeTest = budgeTest;
    this.nfys = [];
    this.keyStack = [];
  }

  public checkedBudge(up: number, key: Key) {
    // console.log 'checkedBudge', up, key
    const { keyStack } = this;
    if (up > 0) {
      keyStack.splice(keyStack.length - up);
    }
    if (key != null) {
      keyStack.push(key);
    }
    // return true
    return this.budgeTest(..._.reverse(keyStack));
  }

  public fullPath(key?: Key) {
    const path = this.keyStack;
    if (key != null) {
      return path.concat([key]);
    } else {
      return _.clone(path);
    }
  }

  public unset(key: string) {
    return this.nfys.push(['unset', this.fullPath(key)]);
  }

  public assign(key: Key, value: Value): number {
    return this.nfys.push(['assign', this.fullPath(key), value]);
  }

  public delete(idx: number, len: number) {
    return this.nfys.push(['delete', this.fullPath(), idx, len]);
  }

  public move(srcIdx: number, dstIdx: number, len: number, reverse: boolean) {
    return this.nfys.push(['move', this.fullPath(), srcIdx, dstIdx, len, reverse]);
  }

  public insert(idx: number, values: AnyArray) {
    return this.nfys.push(['insert', this.fullPath(), idx, values]);
  }

  public replace(idx: number, values: AnyArray) {
    return this.nfys.push(['replace', this.fullPath(), idx, values]);
  }

  public substitute(patches: Patch[]) {
    return this.nfys.push(['substitute', this.fullPath(), patches]);
  }
}

for (const setup of setups) {
  describe(setup.name, () => {
    const wdiff = wdiffFactory(setup.options);
    describe('notify', () => {
      for (const item of items) {
        debug('patch: have=%o, delta=%o', item.have, item.delta);
        const patcher = wdiff.createPatcher(item.patchOptions);
        const budgeTest0 = item.budgeTest0 || (() => true);
        const notifier0 = new MyNotifier(budgeTest0);
        let notifier1: MyNotifier;
        let notifiers: MyNotifier | MyNotifier[];
        if (item.budgeTest1 != null) {
          notifier1 = new MyNotifier(item.budgeTest1);
          notifiers = [notifier0, notifier1];
        } else {
          notifiers = notifier0;
        }
        describe(item.description, () => {
          describe(`patch ${safeRepr(item.have)} with ${safeRepr(item.delta)}`, () => {
            patcher.patch(item.have, item.delta ?? null, notifiers);
            it(`should notify ${safeRepr(item.nfys0)}.`, () => expect(notifier0.nfys).to.be.deep.equal(item.nfys0));
            if (item.budgeTest1 != null) {
              it(`should also notify ${safeRepr(item.nfys1)}.`, () =>
                expect(notifier1.nfys).to.be.deep.equal(item.nfys1));
            }
          });
        });
      }
    });
  });
}
