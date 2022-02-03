import * as _ from 'lodash';
import { expect } from 'chai';

import wdiffFactory from '../src/';
import { safeRepr } from './fixtures/helpers';
import { items } from './fixtures/patch-items';
import { setups } from './fixtures/setups';
import assert from 'assert';
import { PatchError } from '../src/patch';

for (const setup of setups) {
  describe(setup.name, () => {
    const wdiff = wdiffFactory(setup.options);
    describe('patch', () => {
      for (const item of items) {
        const patcher = wdiff.createPatcher(item.patchOptions);
        const have = _.cloneDeep(item.have);
        if (item.failPos != null) {
          it(`should fail to patch ${safeRepr(have)} with ${safeRepr(item.delta)} @${item.failPos}.`, () => {
            let e;
            try {
              patcher.patch(have, item.delta);
            } catch (e0) {
              e = e0;
            }
            assert(e instanceof PatchError);
            expect(e.pos).to.be.equal(item.failPos);
            if (item.failCause) {
              expect(e.cause).to.match(item.failCause);
            }
          });
        } else {
          it(`should patch ${safeRepr(have)} with ${safeRepr(item.delta)} to ${safeRepr(item.wish)}.`, () =>
            expect(patcher.patch(have, item.delta)).to.be.deep.equal(item.wish));
        }
      }
    });
  });
}
