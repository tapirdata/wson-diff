import _ from 'lodash';
import wsonDiff from '../src/';

import { expect } from 'chai';

import items from './fixtures/patch-items';
import setups from './fixtures/setups';


try {
  var util = require('util');
} catch (error) {
  var util = null;
}

let saveRepr = function(x) {
  if (util) {
    return util.inspect(x, {depth: null});
  } else {
    try {
      return JSON.stringify(x);
    } catch (error1) {
      return String(x);
    }
  }
};


for (let i = 0; i < setups.length; i++) {
  const setup = setups[i];
  describe(setup.name, function() {
    let wdiff = wsonDiff(setup.options);
    return describe('patch', () =>
      items.map((item) =>
        (function(item) {
          let patcher = wdiff.createPatcher(item.patchOptions);
          let have = _.cloneDeep(item.have);
          if (item.failPos != null) {
            return it(`should fail to patch ${saveRepr(have)} with '${item.delta}' @${item.failPos}.`, function() {
              try {
                patcher.patch(have, item.delta);
              } catch (e_) {
                var e = e_;
              }
              expect(e).to.be.instanceof(Error);
              expect(e.name).to.be.equal('PatchError');
              expect(e.pos).to.be.equal(item.failPos);
              if (item.failCause) {
                return expect(e.cause).to.match(item.failCause);
              }
            }
            );
          } else {
            return it(`should patch ${saveRepr(have)} with '${item.delta}' to ${saveRepr(item.wish)}.`, () => expect(patcher.patch(have, item.delta)).to.be.deep.equal(item.wish)
            );
          }
        })(item))
    
    );
  }
  );
}


