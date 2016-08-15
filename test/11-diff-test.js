import _ from 'lodash';
let debug = require('debug')('wson-diff:test');

import wsonDiff from '../src/';

import chai from 'chai';
let { expect } = chai;

import setups from './fixtures/setups';
import items from './fixtures/diff-items';


try {
  var util = require('util');
} catch (error) {
  var util = null;
}

let saveRepr = function(x) {
  if (util != null) {
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
    return describe('diff', () =>
      items.map((item) =>
        (function(item) {
          console.log('item=', item);
          let differ = wdiff.createDiffer(item.diffOptions);
          let patcher = wdiff.createPatcher(item.patchOptions);
          let delta = differ.diff(item.have, item.wish);
          debug('diff: have=%o, wish=%o, delta=%o', item.have, item.wish, delta);
          return describe(item.description, function() {
            if (item.hasOwnProperty('delta')) {
              it(`should diff ${saveRepr(item.have)} to ${saveRepr(item.wish)} with ${saveRepr(item.delta)}.`, () => expect(delta).to.be.equal(item.delta)
              );
            }
            if (delta != null) {
              if (!item.noPatch) {
                if (item.wsonClone) {
                  var have = wdiff.WSON.parse(wdiff.WSON.stringify(item.have)); // do a real deep clone (with constructors)
                } else {
                  var have = _.cloneDeep(item.have);
                }
                let got = patcher.patch(have, delta);
                return it(`should patch ${saveRepr(item.have)} with '${delta}' to ${saveRepr(item.wish)}.`, () => expect(got).to.be.deep.equal(item.wish)
                );
              }
            } else {
              return it("should get null delta for no change only", () => expect(item.have).to.be.deep.equal(item.wish)
              );
            }
          }
          );
        })(item))
    
    );
  }
  );
}




