import _ from 'lodash';
let debug = require('debug')('wson-diff:array-diff');

import mdiff from 'mdiff';
import Idxer from './idxer';

class Modifier {

  constructor(ad, mdx, haveBegin, haveLen, wishBegin, wishLen) {
    this.ad = ad;
    this.mdx = mdx;
    this.haveBegin = haveBegin;
    this.haveLen = haveLen;
    this.wishBegin = wishBegin;
    this.wishLen = wishLen;
    this.legs = [];
    this.doneBalance = 0;    // of inserts - # of deletes already performed
    this.restBalance = 0;   // if < 0: extra inserts, if > 0: extra deletes
  }

  addPreLeg(leg) {
    return this.legs.push(leg);
  }

  setupLegs() {
    const { mdx } = this;
    const outLegs = _(this.legs).filter(leg => leg.haveMdx === mdx).sortBy('haveOfs').value();
    const inLegs = _(this.legs).filter(leg => leg.wishMdx === mdx).sortBy('wishOfs').value();
    debug('setupLegs: mdx=%o, outLegs=%o, inLegs=%o', mdx, outLegs, inLegs);

    const legs = [];
    const { haveLen } = this;
    const { wishLen } = this;
    let outLegIdx = 0;
    let outEnd = 0;
    let outGapSum = 0;
    let inLegIdx = 0;
    let inEnd = 0;
    let inGapSum = 0;
    let gapSum = 0;

    const nextOutLeg = function() {
      if (outLegIdx < outLegs.length) {
        const outLeg = outLegs[outLegIdx++];
        outGapSum += outLeg.haveOfs - outEnd;
        outEnd = outLeg.haveOfs + outLeg.len;
        return outLeg;
      } else {
        outGapSum += haveLen - outEnd;
        return null;
      }
    };

    let nextInLeg = function() {
      if (inLegIdx < inLegs.length) {
        let inLeg = inLegs[inLegIdx++];
        inGapSum += inLeg.wishOfs - inEnd;
        inEnd = inLeg.wishOfs + inLeg.len;
        return inLeg;
      } else {
        inGapSum += wishLen - inEnd;
        return null;
      }
    };

    let outLeg = nextOutLeg();
    let inLeg = nextInLeg();

    let rr = 16;
    while (true) {
      let takeIn = false;
      let takeOut = false;
      let extraLen = 0;
      let inLater = inGapSum - outGapSum;
      // debug 'setupLegs:   gapSum=%o outGapSum=%o inGapSum=%o outLeg=%o inLeg=%o', gapSum, outGapSum, inGapSum, outLeg, inLeg
      if (outLeg != null) {
        if (inLeg != null) {
          // both legs: take the first one
          if (inLater > 0) {
            takeOut = true;
          } else {
            takeIn = true;
          }
        } else {
          // only outLeg: take it
          if (inLater < 0) {
            // prevent negative gap by adding a extra delete
            extraLen = inLater;
          }
          takeOut = true;
        }
      } else {
        if (inLeg != null) {
          // only inLeg: take it
          if (inLater > 0) {
            // prevent negative gap by adding an extra insert
            extraLen = inLater;
          }
          takeIn = true;
        } else {
          // no leg
          if (inLater === 0) {
            this.closeGap = inGapSum - gapSum;
            break;
          } else {
            extraLen = inLater;
          }
        }
      }

      if (extraLen < 0) {
        // delete
        legs.push({
          id: this.ad.nextLegId++,
          gap: inGapSum - gapSum,
          len: extraLen,
          done: false
        });
        gapSum = inGapSum;
        outGapSum = gapSum;
        this.restBalance -= inLater;
      } else if (extraLen > 0) {
        // insert
        legs.push({
          id: this.ad.nextLegId++,
          gap: outGapSum - gapSum,
          len: extraLen,
          done: false
        });
        gapSum = outGapSum;
        inGapSum = gapSum;
        this.restBalance -= inLater;
      }
      if (takeOut) {
        legs.push({
          id: outLeg.id,
          gap: outGapSum - gapSum,
          len: -outLeg.len,
          youMdx: outLeg.wishMdx,
          reverse: outLeg.reverse,
          done: false
        });
        gapSum = outGapSum;
        outLeg = nextOutLeg();
      }
      if (takeIn) {
        legs.push({
          id: inLeg.id,
          gap: inGapSum - gapSum,
          len: inLeg.len,
          youMdx: inLeg.haveMdx,
          reverse: inLeg.reverse,
          done: false
        });
        gapSum = inGapSum;
        inLeg = nextInLeg();
      }
      if (--rr === 0) {
        break;
      }
    }

    this.legs = legs;
  }


  getDeletes(meModOff, cb) {
    debug('getDeletes: mdx=%o meModOff=%o', this.mdx, meModOff);
    let { restBalance } = this;
    if (restBalance <= 0) {
      return;
    }
    let haveLoc = (this.haveLen + this.doneBalance) - this.closeGap;
    for (let legIdx = this.legs.length - 1; legIdx >= 0; legIdx--) {
      const leg = this.legs[legIdx];
      debug('getDeletes: restBalance=%o haveLoc=%o leg=%o', restBalance, haveLoc, leg);
      const legLen = leg.len;
      if (legLen > 0) {
        if (leg.done) {
          haveLoc -= legLen;
        }
      } else if (!leg.done) {
        haveLoc += legLen;
        if (leg.youMdx == null) {
          cb(this.haveBegin + meModOff + haveLoc, -legLen);
          this.doneBalance += legLen;
          leg.done = true;
          restBalance += legLen;
          if (restBalance === 0) {
            break;
          }
        }
      }
      haveLoc -= leg.gap;
    }
    this.restBalance = restBalance;
  }

  getInserts(meModOff, cb) {
    debug('getInserts: mdx=%o meModOff=%o have=%o+%o wish=%o+%o', this.mdx, meModOff, this.haveBegin, this.haveLen, this.wishBegin, this.wishLen);
    let { restBalance } = this;
    if (restBalance >= 0) {
      return;
    }
    let haveLoc = (this.haveLen + this.doneBalance) - this.closeGap;
    let wishLoc = this.wishLen - this.closeGap;
    for (let legIdx = this.legs.length - 1; legIdx >= 0; legIdx--) {
      const leg = this.legs[legIdx];
      debug('getInserts:   restBalance=%o haveLoc=%o wishLoc=%o leg=%o', restBalance, haveLoc, wishLoc, leg);
      let legLen = leg.len;
      if (legLen > 0) {
        if (leg.done) {
          haveLoc -= legLen;
        } else if (leg.youMdx == null) {
          cb(this.haveBegin + meModOff + haveLoc, (this.wishBegin + wishLoc) - legLen, legLen);
          this.doneBalance += legLen;
          leg.done = true;
          restBalance += legLen;
          if (restBalance === 0) {
            break;
          }
        }
        wishLoc -= legLen;
      } else if (!leg.done) {
        haveLoc += legLen;
      }
      haveLoc -= leg.gap;
      wishLoc -= leg.gap;
    }
    this.restBalance = restBalance;
  }


  getPatches(meModOff, cb) {
    debug('getPatches: mdx=%o meModOff=%o have=%o+%o wish=%o+%o', this.mdx, meModOff, this.haveBegin, this.haveLen, this.wishBegin, this.wishLen);
    let haveLoc = 0;
    let wishLoc = 0;
    for (let legIdx = 0; legIdx < this.legs.length; legIdx++) {
      const leg = this.legs[legIdx];
      const { gap } = leg;
      const legLen = leg.len;
      if (gap > 0) {
        cb(this.haveBegin + meModOff + haveLoc, this.wishBegin + wishLoc, gap);
      }
      haveLoc += gap;
      wishLoc += gap;
      if (legLen > 0) {
        if (leg.done) {
          haveLoc += legLen;
        }
        wishLoc += legLen;
      } else if (!leg.done) {
        haveLoc -= legLen;
      }
    }
    var gap = this.closeGap;
    if (gap > 0) {
      cb(this.haveBegin + meModOff + haveLoc, this.wishBegin + wishLoc, gap);
    }
  }


  putMove(legId) {
    debug('putMove:   legId=%o', legId);
    let meLoc = 0;
    for (let legIdx = 0; legIdx < this.legs.length; legIdx++) {
      const leg = this.legs[legIdx];
      debug('putMove:     meLoc=%o leg=%o', meLoc, leg);
      meLoc += leg.gap;
      const legLen = leg.len;
      if (leg.id === legId) {
        this.doneBalance += legLen;
        leg.done = true;
        return meLoc;
      } else {
        if (legLen > 0) {
          if (leg.done) {
            meLoc += legLen;
          }
        } else if (!leg.done) {
          meLoc -= legLen;
        }
      }
    } // should never arrive here
  }


  getMoves(meModOff, cb) {
    debug('getMoves: mdx=%o meModOff=%o', this.mdx, meModOff);
    const { ad } = this;
    let meLoc = 0;
    for (let legIdx = 0; legIdx < this.legs.length; legIdx++) {
      const leg = this.legs[legIdx];
      debug('getMoves:   meLoc=%o leg=%o', meLoc, leg);
      meLoc += leg.gap;
      const legLen = leg.len;
      const { youMdx } = leg;
      if ((youMdx != null) && leg.youMdx > this.mdx) {
        let youModifier = ad.modifiers[youMdx];
        const youModOff = meModOff + ad.getModOffDiff(this.mdx, youMdx);
        debug('getMoves:   meModOff=%o, youModOff=%o', meModOff, youModOff);
        const youLoc = youModifier.putMove(leg.id);
        debug('getMoves:   meLoc=%o, youLoc=%o', meLoc, youLoc);
        const meIdx = this.haveBegin + meModOff + meLoc;
        youModifier = youModifier.haveBegin + youModOff + youLoc;
        if (legLen < 0) {
          cb(meIdx, youModifier + legLen, -legLen, leg.reverse);
        } else {
          cb(youModifier, meIdx, legLen, leg.reverse);
          meLoc += legLen;
        }
        this.doneBalance += legLen;
        leg.done = true;
      } else {
        if (legLen > 0) {
          if (leg.done) {
            meLoc += legLen;
          }
        } else if (!leg.done) {
          meLoc -= legLen;
        }
      }
    }
  }
}


class ArrayDiff {

  constructor(state, have, wish) {
    this.state = state;
    this.have = have;
    this.wish = wish;
    this.setupIdxers();
    this.setupModifiers(this.state.differ.arrayLimit);
    if (this.modifiers.length > 0) {
      this.setupLegs();
    }
  }

  setupIdxers() {
    let haveIdxer = new Idxer(this.state, this.have, true, true);
    let wishIdxer = new Idxer(this.state, this.wish, false, haveIdxer.allString);
    if (haveIdxer.allString && !wishIdxer.allString) {
      haveIdxer = new Idxer(this.state, this.have, true, false);
    }
    this.haveIdxer = haveIdxer;
    return this.wishIdxer = wishIdxer;
  }

  setupModifiers(limit) {
    let { haveIdxer, wishIdxer } = this;

    let modifiers = [];
    let wishKeyUses = {};

    let ad = this;
    let scanCb = function(haveBegin, haveEnd, wishBegin, wishEnd) {
      debug('setupModifiers: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd);
      let haveLen = haveEnd - haveBegin;
      let wishLen = wishEnd - wishBegin;
      let mdx = modifiers.length;
      let modifier = new Modifier(ad, mdx, haveBegin, haveLen, wishBegin, wishLen);
      modifiers.push(modifier);

      let wishOfs = 0;
      return (() => { let result = []; while (wishOfs < wishLen) {
        let wishKey = wishIdxer.keys[wishBegin + wishOfs];
        let keyUse = wishKeyUses[wishKey];
        let useTo = [mdx, wishOfs];
        if (keyUse != null) {
          keyUse.push(useTo);
        } else {
          wishKeyUses[wishKey] = [useTo];
        }
        result.push(++wishOfs);
      } return result; })();
    };

    if (_.isFunction(limit)) {
      limit = limit(this.have, this.wish);
    }

    const diffLen = mdiff(haveIdxer.keys, wishIdxer.keys).scanDiff(scanCb, limit);
    this.aborted = (diffLen == null);
    this.modifiers = modifiers;
    this.wishKeyUses = wishKeyUses;
  }

  setupLegs() {
    // debug 'setupLegs: @wishKeyUses=%o', @wishKeyUses
    let { haveIdxer } = this;
    let { wishKeyUses } = this;
    let { modifiers } = this;
    let nextLegId = 0;
    for (let modIdx = 0; modIdx < modifiers.length; modIdx++) {
      var modifier = modifiers[modIdx];
      let { haveBegin } = modifier;
      let { haveLen }  = modifier;
      // debug 'setupLegs: modifier mdx=%o %o+%o', modifier.mdx, haveBegin, haveLen
      let leg = null;
      for (let haveOfs = 0; haveOfs < haveLen; haveOfs++) {
        let key = haveIdxer.keys[haveBegin + haveOfs];
        let wishKeyUse = wishKeyUses[key];
        // debug 'setupLegs:   key=%o wishKeyUse', key, wishKeyUse
        if (wishKeyUse && wishKeyUse.length > 0) {
          let [wishMdx, wishOfs] = wishKeyUse.pop();
          // debug 'setupLegs:   modifier mdx=%o leg=%o wishMdx=%o, haveOfs=%o, wishOfs=%o', modifier.mdx, leg, wishMdx, haveOfs, wishOfs
          let newLeg = true;
          if ((leg != null) && wishMdx === leg.wishMdx && haveOfs === leg.haveOfs + leg.len) {
            if (leg.len === 1) {
              if (wishOfs === leg.wishOfs + 1) {
                ++leg.len;
                newLeg = false;
              } else if (wishOfs === leg.wishOfs - 1) {
                ++leg.len;
                leg.wishOfs = wishOfs;
                newLeg = false;
                leg.reverse = true;
              }
            } else if (leg.reverse) {
              if (wishOfs === leg.wishOfs - 1) {
                ++leg.len;
                leg.wishOfs = wishOfs;
                newLeg = false;
              }
            } else {
              if (wishOfs === leg.wishOfs + leg.len) {
                ++leg.len;
                newLeg = false;
              }
            }
          }
          if (newLeg) {
            if (leg != null) {
              // debug 'setupLegs:   ->%o', leg
              modifiers[leg.haveMdx].addPreLeg(leg);
              modifiers[leg.wishMdx].addPreLeg(leg);
            }
            leg = {
              id: nextLegId++,
              haveMdx: modifier.mdx,
              haveOfs,
              wishMdx,
              wishOfs,
              len: 1,
              reverse: false
            };
          }
        }
      }
      if (leg != null) {
        // debug 'setupLegs:   .->%o', leg
        modifiers[leg.haveMdx].addPreLeg(leg);
        modifiers[leg.wishMdx].addPreLeg(leg);
      }
    }
    this.nextLegId = nextLegId;
    // @debugModifiers 'setupLegs'
    for (let k = 0; k < modifiers.length; k++) {
      var modifier = modifiers[k];
      modifier.setupLegs();
    }
    this.debugModifiers('setupLegs done.');
  }


  getModOffDiff(fromMdx, toMdx) {
    let sum = 0;
    let { modifiers } = this;
    if (fromMdx < toMdx) {
      var idx = fromMdx;
      while (idx < toMdx) {
        sum += modifiers[idx++].doneBalance;
      }
    } else {
      var idx = toMdx;
      while (idx < fromMdx) {
        sum -= modifiers[idx++].doneBalance;
      }
    }
    return sum;
  }

  getDeleteDelta() {
    let delta = '';
    let count = 0;
    let meModOff = this.getModOffDiff(0, this.modifiers.length);
    for (let modIdx = this.modifiers.length - 1; modIdx >= 0; modIdx--) {
      let modifier = this.modifiers[modIdx];
      meModOff -= modifier.doneBalance;
      modifier.getDeletes(meModOff, function(pos, len) {
        debug('getDeleteDelta: pos=%o, len=%o', pos, len);
        delta += count === 0 ? '[d' : '|';
        delta += pos;
        if (len !== 1) {
          delta += `+${len - 1}`;
        }
        return ++count;
      }
      );
    }
    if (count > 0) {
      delta += ']';
    }

    return delta;
  }

  getInsertDelta() {
    let delta = '';
    let count = 0;
    let meModOff = this.getModOffDiff(0, this.modifiers.length);
    let { wishIdxer } = this;
    debug('getInsertDelta: meModOff=%o', meModOff);
    for (let modIdx = this.modifiers.length - 1; modIdx >= 0; modIdx--) {
      let modifier = this.modifiers[modIdx];
      meModOff -= modifier.doneBalance;
      modifier.getInserts(meModOff, function(havePos, wishPos, len) {
        debug('getInsertDelta: havePos=%o, wishPos=%o, len=%o', havePos, wishPos, len);
        delta += count === 0 ? '[i' : '|';
        delta += havePos;
        for (let i = 0; i < len; i++) {
          delta += `:${wishIdxer.getItem(wishPos + i)}`;
        }
        return ++count;
      }
      );
    }
    if (count > 0) {
      delta += ']';
    }

    return delta;
  }

  getPatchDelta() {
    let delta = '';
    let count = 0;
    let meModOff = 0;
    let { have } = this;
    let { wish } = this;
    let { state } = this;
    debug('getPatchDelta: meModOff=%o', meModOff);
    for (let modIdx = 0; modIdx < this.modifiers.length; modIdx++) {
      let modifier = this.modifiers[modIdx];
      modifier.getPatches(meModOff, function(havePos, wishPos, len) {
        debug('getPatchDelta: havePos=%o, wishPos=%o, len=%o', havePos, wishPos, len);
        delta += count === 0 ? '[r' : '|';
        delta += havePos;
        let canChain = true;
        for (let i = 0; i < len; i++) {
          let iDelta = state.getDelta(
            have[havePos + i],
            wish[wishPos + i]
          );
          if (iDelta[0] !== ':') {
            canChain = false;
          }
          if (i > 0 && !canChain) {
            delta += `|${havePos + i}`;
          }
          delta += iDelta;
        }
        return ++count;
      }
      );
      meModOff += modifier.doneBalance;
    }
    if (count > 0) {
      delta += ']';
    }
    return delta;
  }


  getMoveDelta() {
    let delta = '';
    let count = 0;
    let meModOff = 0;
    for (let modIdx = 0; modIdx < this.modifiers.length; modIdx++) {
      let modifier = this.modifiers[modIdx];
      modifier.getMoves(meModOff, function(srcPos, dstPos, len, reverse) {
        debug('getMoveDelta: srcPos=%o, dstPos=%o, len=%o reverse=%o', srcPos, dstPos, len, reverse);
        delta += count === 0 ? '[m' : '|';
        delta += srcPos;
        if (len !== 1) {
          delta += (reverse ? '-' : '+') + (len - 1);
        }
        delta += `@${dstPos}`;
        return ++count;
      }
      );
      meModOff += modifier.doneBalance;
    }
    if (count > 0) {
      delta += ']';
    }
    // @debugModifiers 'getMoveDelta done.'
    return delta;
  }

  getDelta(isRoot) {
    if (this.modifiers.length === 0) {
      return null;
    } else {
      let delta = isRoot ? '|' : '';
      delta += this.getDeleteDelta();
      delta += this.getMoveDelta();
      delta += this.getInsertDelta();
      delta += this.getPatchDelta();
      return delta;
    }
  }

  debugModifiers(title) {
    debug(title + ' modifiers:');
    return this.modifiers.map((modifier) =>
      (debug('  mdx=%o have=%o+%o wish=%o+%o, restBalance=%o', modifier.mdx, modifier.haveBegin, modifier.haveLen, modifier.wishBegin, modifier.wishLen, modifier.restBalance),
      modifier.legs.map((leg) =>
        debug('    %o', leg)),
      debug('  closeGap=%o', modifier.closeGap)));
  }
}


export default ArrayDiff;

