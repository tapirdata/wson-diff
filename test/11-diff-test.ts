import * as _ from 'lodash';
import { expect } from 'chai';
import debugFactory = require('debug');

import wdiffFactory from '../src/';
import { items } from './fixtures/diff-items';
import { safeRepr } from './fixtures/helpers';
import { setups } from './fixtures/setups';

const _debug = debugFactory('wson-diff:test');

for (const setup of setups) {
  describe(setup.name, () => {
    const wdiff = wdiffFactory(setup.options);
    describe('diff', () => {
      for (const item of items) {
        const differ = wdiff.createDiffer(item.diffOptions);
        const patcher = wdiff.createPatcher();
        const delta = differ.diff(item.have, item.wish);
        describe(item.description, () => {
          if (_.has(item, 'delta')) {
            it(`should diff ${safeRepr(item.have)} to ${safeRepr(item.wish)} with ${safeRepr(item.delta)}.`, () =>
              expect(delta).to.be.equal(item.delta));
          }
          if (delta != null) {
            if (!item.noPatch) {
              let have;
              if (item.wsonClone) {
                have = wdiff.WSON.parse(wdiff.WSON.stringify(item.have)); // do a real deep clone (with constructors)
              } else {
                have = _.cloneDeep(item.have);
              }
              const got = patcher.patch(have, delta);
              it(`should patch ${safeRepr(item.have)} with '${delta}' to ${safeRepr(item.wish)}.`, () =>
                expect(got).to.be.deep.equal(item.wish));
            }
          } else {
            it('should get null delta for no change only', () => expect(item.have).to.be.deep.equal(item.wish));
          }
        });
      }
    });
  });
}
