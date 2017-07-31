// tslint:disable:max-classes-per-file
import debugFactory = require("debug")
const debug = debugFactory("wson-diff:array-diff")
import _ = require("lodash")
import mdiff from "mdiff"

import { State } from "./diff"
import { Idxer } from "./idxer"

export type ArrayLimiter = (have: any[], wish: any[]) => number
export type MdxOfs = [number, number]
export type KeyUse = MdxOfs[]
export interface KeyUses { [key: string]: KeyUse }

export interface Leg {
  id: number
  gap: number
  haveMdx: number
  haveOfs: number
  wishMdx: number
  wishOfs: number
  youMdx: number
  len: number
  reverse: boolean
  done: boolean
}

export class Modifier {

  public ad: ArrayDiff
  public mdx: number
  public haveBegin: number
  public haveLen: number
  public wishBegin: number
  public wishLen: number
  public legs: Leg[]
  public doneBalance: number
  public restBalance: number
  public closeGap: number

  constructor(ad: ArrayDiff, mdx: number, haveBegin: number, haveLen: number, wishBegin: number, wishLen: number) {
    this.ad = ad
    this.mdx = mdx
    this.haveBegin = haveBegin
    this.haveLen = haveLen
    this.wishBegin = wishBegin
    this.wishLen = wishLen
    this.legs = []
    this.doneBalance = 0    // of inserts - # of deletes already performed
    this.restBalance = 0   // if < 0: extra inserts, if > 0: extra deletes
  }

  public addPreLeg(leg: Leg) {
    return this.legs.push(leg)
  }

  public setupLegs() {
    const { mdx } = this
    const outLegs: Leg[] = _(this.legs).filter((leg) => leg.haveMdx === mdx).sortBy("haveOfs").value()
    const inLegs: Leg[] = _(this.legs).filter((leg) => leg.wishMdx === mdx).sortBy("wishOfs").value()
    debug("setupLegs: mdx=%o, outLegs=%o, inLegs=%o", mdx, outLegs, inLegs)

    const legs: Leg[] = []
    const { haveLen } = this
    const { wishLen } = this
    let outLegIdx = 0
    let outEnd = 0
    let outGapSum = 0
    let inLegIdx = 0
    let inEnd = 0
    let inGapSum = 0
    let gapSum = 0

    function nextOutLeg() {
      if (outLegIdx < outLegs.length) {
        const resultLeg = outLegs[outLegIdx++]
        outGapSum += resultLeg.haveOfs - outEnd
        outEnd = resultLeg.haveOfs + resultLeg.len
        return resultLeg
      } else {
        outGapSum += haveLen - outEnd
        return null
      }
    }

    function nextInLeg() {
      if (inLegIdx < inLegs.length) {
        const resultLeg = inLegs[inLegIdx++]
        inGapSum += resultLeg.wishOfs - inEnd
        inEnd = resultLeg.wishOfs + resultLeg.len
        return resultLeg
      } else {
        inGapSum += wishLen - inEnd
        return null
      }
    }

    let outLeg = nextOutLeg()
    let inLeg = nextInLeg()

    let rr = 16
    while (true) {
      let takeIn = false
      let takeOut = false
      let extraLen = 0
      const inLater = inGapSum - outGapSum
      // debug 'setupLegs:   gapSum=%o outGapSum=%o inGapSum=%o outLeg=%o inLeg=%o',
      //   gapSum, outGapSum, inGapSum, outLeg, inLeg
      if (outLeg != null) {
        if (inLeg != null) {
          // both legs: take the first one
          if (inLater > 0) {
            takeOut = true
          } else {
            takeIn = true
          }
        } else {
          // only outLeg: take it
          if (inLater < 0) {
            // prevent negative gap by adding a extra delete
            extraLen = inLater
          }
          takeOut = true
        }
      } else {
        if (inLeg != null) {
          // only inLeg: take it
          if (inLater > 0) {
            // prevent negative gap by adding an extra insert
            extraLen = inLater
          }
          takeIn = true
        } else {
          // no leg
          if (inLater === 0) {
            this.closeGap = inGapSum - gapSum
            break
          } else {
            extraLen = inLater
          }
        }
      }

      if (extraLen < 0) {
        // delete
        legs.push({
          id: this.ad.nextLegId++,
          gap: inGapSum - gapSum,
          len: extraLen,
          done: false,
        } as Leg)
        gapSum = inGapSum
        outGapSum = gapSum
        this.restBalance -= inLater
      } else if (extraLen > 0) {
        // insert
        legs.push({
          id: this.ad.nextLegId++,
          gap: outGapSum - gapSum,
          len: extraLen,
          done: false,
        } as Leg)
        gapSum = outGapSum
        inGapSum = gapSum
        this.restBalance -= inLater
      }
      if (takeOut) {
        legs.push({
          id: outLeg!.id,
          gap: outGapSum - gapSum,
          len: -outLeg!.len,
          youMdx: outLeg!.wishMdx,
          reverse: outLeg!.reverse,
          done: false,
        } as Leg)
        gapSum = outGapSum
        outLeg = nextOutLeg()
      }
      if (takeIn) {
        legs.push({
          id: inLeg!.id,
          gap: inGapSum - gapSum,
          len: inLeg!.len,
          youMdx: inLeg!.haveMdx,
          reverse: inLeg!.reverse,
          done: false,
        } as Leg)
        gapSum = inGapSum
        inLeg = nextInLeg()
      }
      if (--rr === 0) {
        break
      }
    }

    this.legs = legs
  }

  public getDeletes(meModOff: number, cb: (pos: number, len: number) => void) {
    debug("getDeletes: mdx=%o meModOff=%o", this.mdx, meModOff)
    let { restBalance } = this
    if (restBalance <= 0) {
      return
    }
    let haveLoc = (this.haveLen + this.doneBalance) - this.closeGap
    for (let legIdx = this.legs.length - 1; legIdx >= 0; legIdx--) {
      const leg = this.legs[legIdx]
      debug("getDeletes: restBalance=%o haveLoc=%o leg=%o", restBalance, haveLoc, leg)
      const legLen = leg.len
      if (legLen > 0) {
        if (leg.done) {
          haveLoc -= legLen
        }
      } else if (!leg.done) {
        haveLoc += legLen
        if (leg.youMdx == null) {
          cb(this.haveBegin + meModOff + haveLoc, -legLen)
          this.doneBalance += legLen
          leg.done = true
          restBalance += legLen
          if (restBalance === 0) {
            break
          }
        }
      }
      haveLoc -= leg.gap
    }
    this.restBalance = restBalance
  }

  public getInserts(meModOff: number, cb: (havePos: number, wishPos: number, len: number) => void) {
    debug("getInserts: mdx=%o meModOff=%o have=%o+%o wish=%o+%o",
      this.mdx, meModOff, this.haveBegin, this.haveLen, this.wishBegin, this.wishLen)
    let { restBalance } = this
    if (restBalance >= 0) {
      return
    }
    let haveLoc = (this.haveLen + this.doneBalance) - this.closeGap
    let wishLoc = this.wishLen - this.closeGap
    for (let legIdx = this.legs.length - 1; legIdx >= 0; legIdx--) {
      const leg = this.legs[legIdx]
      debug("getInserts:   restBalance=%o haveLoc=%o wishLoc=%o leg=%o", restBalance, haveLoc, wishLoc, leg)
      const legLen = leg.len
      if (legLen > 0) {
        if (leg.done) {
          haveLoc -= legLen
        } else if (leg.youMdx == null) {
          cb(this.haveBegin + meModOff + haveLoc, (this.wishBegin + wishLoc) - legLen, legLen)
          this.doneBalance += legLen
          leg.done = true
          restBalance += legLen
          if (restBalance === 0) {
            break
          }
        }
        wishLoc -= legLen
      } else if (!leg.done) {
        haveLoc += legLen
      }
      haveLoc -= leg.gap
      wishLoc -= leg.gap
    }
    this.restBalance = restBalance
  }

  public getPatches(meModOff: number, cb: (havePos: number, wishPos: number, len: number) => void) {
    debug("getPatches: mdx=%o meModOff=%o have=%o+%o wish=%o+%o",
      this.mdx, meModOff, this.haveBegin, this.haveLen, this.wishBegin, this.wishLen)
    let haveLoc = 0
    let wishLoc = 0
    for (const leg of this.legs) {
      const { gap } = leg
      const legLen = leg.len
      if (gap > 0) {
        cb(this.haveBegin + meModOff + haveLoc, this.wishBegin + wishLoc, gap)
      }
      haveLoc += gap
      wishLoc += gap
      if (legLen > 0) {
        if (leg.done) {
          haveLoc += legLen
        }
        wishLoc += legLen
      } else if (!leg.done) {
        haveLoc -= legLen
      }
    }
    const { closeGap } = this
    if (closeGap > 0) {
      cb(this.haveBegin + meModOff + haveLoc, this.wishBegin + wishLoc, closeGap)
    }
  }

  public putMove(legId: number) {
    debug("putMove:   legId=%o", legId)
    let meLoc = 0
    for (const leg of this.legs) {
      debug("putMove:     meLoc=%o leg=%o", meLoc, leg)
      meLoc += leg.gap
      const legLen = leg.len
      if (leg.id === legId) {
        this.doneBalance += legLen
        leg.done = true
        return meLoc
      } else {
        if (legLen > 0) {
          if (leg.done) {
            meLoc += legLen
          }
        } else if (!leg.done) {
          meLoc -= legLen
        }
      }
    } // should never arrive here
  }

  public getMoves(meModOff: number, cb: (srcPos: number, dstPos: number, len: number, reverse: boolean) => void) {
    debug("getMoves: mdx=%o meModOff=%o", this.mdx, meModOff)
    const { ad } = this
    let meLoc = 0
    for (const leg of this.legs) {
      debug("getMoves:   meLoc=%o leg=%o", meLoc, leg)
      meLoc += leg.gap
      const legLen = leg.len
      const { youMdx } = leg
      if ((youMdx != null) && leg.youMdx > this.mdx) {
        const youModifier = ad.modifiers[youMdx]
        const youModOff = meModOff + ad.getModOffDiff(this.mdx, youMdx)
        debug("getMoves:   meModOff=%o, youModOff=%o", meModOff, youModOff)
        const youLoc = youModifier.putMove(leg.id)
        debug("getMoves:   meLoc=%o, youLoc=%o", meLoc, youLoc)
        const meIdx = this.haveBegin + meModOff + meLoc
        const youIdx = youModifier.haveBegin + youModOff + youLoc!
        if (legLen < 0) {
          cb(meIdx, youIdx + legLen, -legLen, leg.reverse)
        } else {
          cb(youIdx, meIdx, legLen, leg.reverse)
          meLoc += legLen
        }
        this.doneBalance += legLen
        leg.done = true
      } else {
        if (legLen > 0) {
          if (leg.done) {
            meLoc += legLen
          }
        } else if (!leg.done) {
          meLoc -= legLen
        }
      }
    }
  }
}

export class ArrayDiff {

  public state: State
  public have: any[]
  public wish: any[]
  public haveIdxer: Idxer
  public wishIdxer: Idxer
  public aborted: boolean
  public nextLegId: number
  public modifiers: Modifier[]
  public wishKeyUses: KeyUses

  constructor(state: State, have: any[], wish: any[]) {
    this.state = state
    this.have = have
    this.wish = wish
    this.setupIdxers()
    this.setupModifiers(this.state.differ.arrayLimit)
    if (this.modifiers.length > 0) {
      this.setupLegs()
    }
  }

  public setupIdxers() {
    let haveIdxer = new Idxer(this.state, this.have, true, true)
    const wishIdxer = new Idxer(this.state, this.wish, false, haveIdxer.allString)
    if (haveIdxer.allString && !wishIdxer.allString) {
      haveIdxer = new Idxer(this.state, this.have, true, false)
    }
    this.haveIdxer = haveIdxer
    this.wishIdxer = wishIdxer
  }

  public setupModifiers(limit: number | ArrayLimiter | undefined ) {
    const { haveIdxer, wishIdxer } = this

    const modifiers: Modifier[] = []
    const wishKeyUses: KeyUses = {}

    const ad = this
    function scanCb(haveBegin: number, haveEnd: number, wishBegin: number, wishEnd: number) {
      debug("setupModifiers: %o..%o %o..%o", haveBegin, haveEnd, wishBegin, wishEnd)
      const haveLen = haveEnd - haveBegin
      const wishLen = wishEnd - wishBegin
      const mdx = modifiers.length
      const modifier = new Modifier(ad, mdx, haveBegin, haveLen, wishBegin, wishLen)
      modifiers.push(modifier)

      let wishOfs = 0
      return (() => { const result: number[] = []; while (wishOfs < wishLen) {
        const wishKey = wishIdxer.keys[wishBegin + wishOfs]
        const keyUse: KeyUse = wishKeyUses[wishKey]
        const useTo: MdxOfs = [mdx, wishOfs]
        if (keyUse != null) {
          keyUse.push(useTo)
        } else {
          wishKeyUses[wishKey] = [useTo]
        }
        result.push(++wishOfs)
      }               return result })()
    }

    if (_.isFunction(limit)) {
      limit = limit(this.have, this.wish)
    }

    const diffLen = mdiff(haveIdxer.keys, wishIdxer.keys).scanDiff(scanCb, limit)
    this.aborted = (diffLen == null)
    this.modifiers = modifiers
    this.wishKeyUses = wishKeyUses
  }

  public setupLegs() {
    // debug 'setupLegs: @wishKeyUses=%o', @wishKeyUses
    const { haveIdxer } = this
    const { wishKeyUses } = this
    const { modifiers } = this
    let nextLegId = 0
    for (const modifier of  modifiers) {
      const { haveBegin } = modifier
      const { haveLen }  = modifier
      // debug 'setupLegs: modifier mdx=%o %o+%o', modifier.mdx, haveBegin, haveLen
      let leg: Leg | null = null
      for (let haveOfs = 0; haveOfs < haveLen; haveOfs++) {
        const key = haveIdxer.keys[haveBegin + haveOfs]
        const wishKeyUse: KeyUse = wishKeyUses[key]
        // debug 'setupLegs:   key=%o wishKeyUse', key, wishKeyUse
        if (wishKeyUse && wishKeyUse.length > 0) {
          const [wishMdx, wishOfs] = wishKeyUse.pop() as MdxOfs
          // debug 'setupLegs:   modifier mdx=%o leg=%o wishMdx=%o, haveOfs=%o, wishOfs=%o',
          //   modifier.mdx, leg, wishMdx, haveOfs, wishOfs
          let newLeg = true
          if ((leg != null) && wishMdx === leg.wishMdx && haveOfs === leg.haveOfs + leg.len) {
            if (leg.len === 1) {
              if (wishOfs === leg.wishOfs + 1) {
                ++leg.len
                newLeg = false
              } else if (wishOfs === leg.wishOfs - 1) {
                ++leg.len
                leg.wishOfs = wishOfs
                newLeg = false
                leg.reverse = true
              }
            } else if (leg.reverse) {
              if (wishOfs === leg.wishOfs - 1) {
                ++leg.len
                leg.wishOfs = wishOfs
                newLeg = false
              }
            } else {
              if (wishOfs === leg.wishOfs + leg.len) {
                ++leg.len
                newLeg = false
              }
            }
          }
          if (newLeg) {
            if (leg != null) {
              // debug 'setupLegs:   ->%o', leg
              modifiers[leg.haveMdx].addPreLeg(leg)
              modifiers[leg.wishMdx].addPreLeg(leg)
            }
            leg = {
              id: nextLegId++,
              haveMdx: modifier.mdx,
              haveOfs,
              wishMdx,
              wishOfs,
              len: 1,
              reverse: false,
            } as Leg
          }
        }
      }
      if (leg != null) {
        // debug 'setupLegs:   .->%o', leg
        modifiers[leg.haveMdx].addPreLeg(leg)
        modifiers[leg.wishMdx].addPreLeg(leg)
      }
    }
    this.nextLegId = nextLegId
    // @debugModifiers 'setupLegs'
    for (const modifier of modifiers) {
      modifier.setupLegs()
    }
    this.debugModifiers("setupLegs done.")
  }

  public getModOffDiff(fromMdx: number, toMdx: number) {
    let sum = 0
    const { modifiers } = this
    if (fromMdx < toMdx) {
      let idx = fromMdx
      while (idx < toMdx) {
        sum += modifiers[idx++].doneBalance
      }
    } else {
      let idx = toMdx
      while (idx < fromMdx) {
        sum -= modifiers[idx++].doneBalance
      }
    }
    return sum
  }

  public getDeleteDelta() {
    let delta = ""
    let count = 0
    let meModOff = this.getModOffDiff(0, this.modifiers.length)
    for (let modIdx = this.modifiers.length - 1; modIdx >= 0; modIdx--) {
      const modifier = this.modifiers[modIdx]
      meModOff -= modifier.doneBalance
      modifier.getDeletes(meModOff, (pos, len) => {
        debug("getDeleteDelta: pos=%o, len=%o", pos, len)
        delta += count === 0 ? "[d" : "|"
        delta += pos
        if (len !== 1) {
          delta += `+${len - 1}`
        }
        return ++count
      },
      )
    }
    if (count > 0) {
      delta += "]"
    }

    return delta
  }

  public getInsertDelta() {
    let delta = ""
    let count = 0
    let meModOff = this.getModOffDiff(0, this.modifiers.length)
    const { wishIdxer } = this
    debug("getInsertDelta: meModOff=%o", meModOff)
    for (let modIdx = this.modifiers.length - 1; modIdx >= 0; modIdx--) {
      const modifier = this.modifiers[modIdx]
      meModOff -= modifier.doneBalance
      modifier.getInserts(meModOff, (havePos, wishPos, len) => {
        debug("getInsertDelta: havePos=%o, wishPos=%o, len=%o", havePos, wishPos, len)
        delta += count === 0 ? "[i" : "|"
        delta += havePos
        for (let i = 0; i < len; i++) {
          delta += `:${wishIdxer.getItem(wishPos + i)}`
        }
        return ++count
      },
      )
    }
    if (count > 0) {
      delta += "]"
    }

    return delta
  }

  public getPatchDelta() {
    let delta = ""
    let count = 0
    let meModOff = 0
    const { have } = this
    const { wish } = this
    const { state } = this
    debug("getPatchDelta: meModOff=%o", meModOff)
    for (const modifier of this.modifiers) {
      modifier.getPatches(meModOff, (havePos, wishPos, len) => {
        debug("getPatchDelta: havePos=%o, wishPos=%o, len=%o", havePos, wishPos, len)
        delta += count === 0 ? "[r" : "|"
        delta += havePos
        let canChain = true
        for (let i = 0; i < len; i++) {
          const iDelta = state.getDelta(
            have[havePos + i],
            wish[wishPos + i],
            false,
          )
          if (iDelta![0] !== ":") {
            canChain = false
          }
          if (i > 0 && !canChain) {
            delta += `|${havePos + i}`
          }
          delta += iDelta
        }
        return ++count
      },
      )
      meModOff += modifier.doneBalance
    }
    if (count > 0) {
      delta += "]"
    }
    return delta
  }

  public getMoveDelta() {
    let delta = ""
    let count = 0
    let meModOff = 0
    for (const modifier of this.modifiers) {
      modifier.getMoves(meModOff, (srcPos, dstPos, len, reverse) => {
        debug("getMoveDelta: srcPos=%o, dstPos=%o, len=%o reverse=%o", srcPos, dstPos, len, reverse)
        delta += count === 0 ? "[m" : "|"
        delta += srcPos
        if (len !== 1) {
          delta += (reverse ? "-" : "+") + (len - 1)
        }
        delta += `@${dstPos}`
        return ++count
      },
      )
      meModOff += modifier.doneBalance
    }
    if (count > 0) {
      delta += "]"
    }
    // @debugModifiers 'getMoveDelta done.'
    return delta
  }

  public getDelta(isRoot: boolean) {
    if (this.modifiers.length === 0) {
      return null
    } else {
      let delta = isRoot ? "|" : ""
      delta += this.getDeleteDelta()
      delta += this.getMoveDelta()
      delta += this.getInsertDelta()
      delta += this.getPatchDelta()
      return delta
    }
  }

  public debugModifiers(title: string) {
    debug(title + " modifiers:")
    return this.modifiers.map((modifier) =>
      (debug("  mdx=%o have=%o+%o wish=%o+%o, restBalance=%o",
        modifier.mdx, modifier.haveBegin, modifier.haveLen, modifier.wishBegin, modifier.wishLen, modifier.restBalance),
      modifier.legs.map((leg) =>
        debug("    %o", leg)),
      debug("  closeGap=%o", modifier.closeGap)))
  }
}
