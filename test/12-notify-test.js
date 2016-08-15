import _ from 'lodash';
let debug = require('debug')('wson-diff:test');

import wsonDiff from '../src/';

import chai from 'chai';
let { expect } = chai;

import setups from './fixtures/setups';
import items from './fixtures/notify-items';


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


class Notifier {

  constructor(budgeTest) {
    this.budgeTest = budgeTest;
    this.nfys = [];
    this.keyStack = [];
  }

  checkedBudge(up, key) {
    // console.log 'checkedBudge', up, key
    let { keyStack } = this;
    if (up > 0) {
      keyStack.splice(keyStack.length - up);
    }
    if (key != null) {
      keyStack.push(key);
    }
    return this.budgeTest.apply(this, _(keyStack).reverse().value());
  }

  fullPath(key) {
    let path = this.keyStack;
    if (key != null) {
      return path.concat([key]);
    } else {
      return _.clone(path);
    }
  }

  unset(key) {
    return this.nfys.push(['unset', this.fullPath(key)]);
  }
  assign(key, value) {
    return this.nfys.push(['assign', this.fullPath(key), value]);
  }

  delete(idx, len) {
    return this.nfys.push(['delete', this.fullPath(), idx, len]);
  }
  move(srcIdx, dstIdx, len, reverse) {
    return this.nfys.push(['move', this.fullPath(), srcIdx, dstIdx, len, reverse]);
  }
  insert(idx, values) {
    return this.nfys.push(['insert', this.fullPath(), idx, values]);
  }
  replace(idx, values) {
    return this.nfys.push(['replace', this.fullPath(), idx, values]);
  }

  substitute(patches) {
    return this.nfys.push(['substitute', this.fullPath(), patches]);
  }
}


for (let i = 0; i < setups.length; i++) {
  const setup = setups[i];
  describe(setup.name, function() {
    let wdiff = wsonDiff(setup.options);
    return describe('notify', () =>
      items.map((item) =>
        (function(item) {
          debug('patch: have=%o, delta=%o', item.have, item.delta);
          let patcher = wdiff.createPatcher(item.patchOptions);
          let notifier0 = new Notifier(item.budgeTest0);
          if (item.budgeTest1 != null) {
            var notifier1 = new Notifier(item.budgeTest1);
            var notifiers = [notifier0, notifier1];
          } else {  
            var notifiers = notifier0;
          }
          return describe(item.description, () =>
            describe(`patch ${saveRepr(item.have)} with '${item.delta}'`, function() {
              patcher.patch(item.have, item.delta, notifiers);
              it(`should notify ${saveRepr(item.nfys0)}.`, () => expect(notifier0.nfys).to.be.deep.equal(item.nfys0)
              );
              if (item.budgeTest1 != null) {  
                return it(`should also notify ${saveRepr(item.nfys1)}.`, () => expect(notifier1.nfys).to.be.deep.equal(item.nfys1)
                );
              }
            }
            )
          
          );
        })(item))
    
    );
  }
  );
}

