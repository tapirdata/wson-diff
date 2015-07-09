_ = require 'lodash'
debug = require('debug') 'wson-diff:array-diff'

mdiff = require 'mdiff'
Idxer = require './idxer'

class Modifier

  constructor: (@ad, @mdx, @haveBegin, @haveLen, @wishBegin, @wishLen) ->
    @legs = []
    @doneBalance = 0    # of inserts - # of deletes already performed
    @restBalance = 0   # if < 0: extra inserts, if > 0: extra deletes

  addPreLeg: (leg) ->
    @legs.push leg

  setupLegs: ->
    # debug 'setupLegs: mdx=%o legs:', @mdx
    # for leg in @legs
    #   debug '  %o', leg
    mdx = @mdx
    outLegs = _(@legs).filter((leg) -> leg.haveMdx == mdx).sortBy('haveOfs').value()
    inLegs = _(@legs).filter((leg) -> leg.wishMdx == mdx).sortBy('wishOfs').value()
    debug 'setupLegs: mdx=%o, outLegs=%o, inLegs=%o', mdx, outLegs, inLegs

    legs = []
    haveLen = @haveLen
    wishLen = @wishLen
    outLegIdx = 0
    outEnd = 0
    outGapSum = 0
    inLegIdx = 0
    inEnd = 0
    inGapSum = 0
    gapSum = 0

    nextOutLeg = ->
      if outLegIdx < outLegs.length
        outLeg = outLegs[outLegIdx++]
        outGapSum += outLeg.haveOfs - outEnd
        outEnd = outLeg.haveOfs + outLeg.len
        outLeg
      else
        outGapSum += haveLen - outEnd
        null

    nextInLeg = ->
      if inLegIdx < inLegs.length
        inLeg = inLegs[inLegIdx++]
        inGapSum += inLeg.wishOfs - inEnd
        inEnd = inLeg.wishOfs + inLeg.len
        inLeg
      else
        inGapSum += wishLen - inEnd
        null

    outLeg = nextOutLeg()
    inLeg = nextInLeg()

    rr = 16
    loop
      takeIn = false
      takeOut = false
      extraLen = 0
      inLater = inGapSum - outGapSum
      # debug 'setupLegs:   gapSum=%o outGapSum=%o inGapSum=%o outLeg=%o inLeg=%o', gapSum, outGapSum, inGapSum, outLeg, inLeg
      if outLeg?
        if inLeg?
          # both legs: take the first one
          if inLater > 0
            takeOut = true
          else
            takeIn = true
        else
          # only outLeg: take it
          if inLater < 0
            # prevent negative gap by adding a extra delete
            extraLen = inLater
          takeOut = true
      else
        if inLeg?
          # only inLeg: take it
          if inLater > 0
            # prevent negative gap by adding an extra insert
            extraLen = inLater
          takeIn = true
        else
          # no leg
          if inLater == 0
            @closeGap = inGapSum - gapSum
            break
          else
            extraLen = inLater

      if extraLen < 0
        # delete
        legs.push
          id: @ad.nextLegId++
          gap: inGapSum - gapSum
          len: extraLen
          done: false
        gapSum = inGapSum
        outGapSum = gapSum
        @restBalance -= inLater
      else if extraLen > 0
        # insert
        legs.push
          id: @ad.nextLegId++
          gap: outGapSum - gapSum
          len: extraLen
          done: false
        gapSum = outGapSum
        inGapSum = gapSum
        @restBalance -= inLater
      if takeOut
        legs.push
          id: outLeg.id
          gap: outGapSum - gapSum
          len: -outLeg.len
          youMdx: outLeg.wishMdx
          done: false
        gapSum = outGapSum
        outLeg = nextOutLeg()
      if takeIn
        legs.push
          id: inLeg.id
          gap: inGapSum - gapSum
          len: inLeg.len
          youMdx: inLeg.haveMdx
          done: false
        gapSum = inGapSum
        inLeg = nextInLeg()
      if --rr == 0
        break

    @legs = legs
    return


  getDeletes: (meModOff, cb) ->
    debug 'getMoves: mdx=%o meModOff=%o', @mdx, meModOff
    restBalance = @restBalance
    if restBalance <= 0
      return
    haveLoc = @haveLen + @doneBalance - @closeGap
    for leg in @legs by -1
      debug 'getDeletes: restBalance=%o haveLoc=%o leg=%o', restBalance, haveLoc, leg
      legLen = leg.len
      if legLen > 0
        if leg.done
          haveLoc -= legLen
      else if not leg.done
        haveLoc += legLen
        if not leg.youMdx?
          cb @haveBegin + meModOff + haveLoc, -legLen
          @doneBalance += legLen
          leg.done = true
          restBalance += legLen
          if restBalance == 0
            break
      haveLoc -= leg.gap
    @restBalance = restBalance
    return

  getInserts: (meModOff, cb) ->
    debug 'getInserts: mdx=%o meModOff=%o have=%o~%o wish=%o~%o', @mdx, meModOff, @haveBegin, @haveLen, @wishBegin, @wishLen
    restBalance = @restBalance
    if restBalance >= 0
      return
    haveLoc = @haveLen + @doneBalance - @closeGap
    wishLoc = @wishLen - @closeGap
    for leg in @legs by -1
      debug 'getInserts:   restBalance=%o haveLoc=%o wishLoc=%o leg=%o', restBalance, haveLoc, wishLoc, leg
      legLen = leg.len
      if legLen > 0
        if leg.done
          haveLoc -= legLen
        else if not leg.youMdx?
          cb @haveBegin + meModOff + haveLoc, @wishBegin + wishLoc - legLen, legLen
          @doneBalance += legLen
          leg.done = true
          restBalance += legLen
          if restBalance == 0
            break
        wishLoc -= legLen
      else if not leg.done
        haveLoc += legLen
      haveLoc -= leg.gap
      wishLoc -= leg.gap
    @restBalance = restBalance
    return


  getPatches: (meModOff, cb) ->
    debug 'getPatches: mdx=%o meModOff=%o have=%o~%o wish=%o~%o', @mdx, meModOff, @haveBegin, @haveLen, @wishBegin, @wishLen
    haveLoc = 0
    wishLoc = 0
    for leg in @legs
      gap = leg.gap
      legLen = leg.len
      if gap > 0
        cb @haveBegin + meModOff + haveLoc, @wishBegin + wishLoc, gap
      haveLoc += gap
      wishLoc += gap
      if legLen > 0
        if leg.done
          haveLoc += legLen
        wishLoc += legLen
      else if not leg.done
        haveLoc -= legLen
    gap = @closeGap
    if gap > 0
      cb @haveBegin + meModOff + haveLoc, @wishBegin + wishLoc, gap
    return


  putMove: (legId) ->
    debug 'putMove:   legId=%o', legId
    meLoc = 0
    for leg in @legs
      debug 'putMove:     meLoc=%o leg=%o', meLoc, leg
      meLoc += leg.gap
      legLen = leg.len
      if leg.id == legId
        @doneBalance += legLen
        leg.done = true
        return meLoc
      else
        if legLen > 0
          if leg.done
            meLoc += legLen
        else if not leg.done
          meLoc -= legLen
    return # should never arrive here


  getMoves: (meModOff, cb) ->
    debug 'getMoves: mdx=%o meModOff=%o', @mdx, meModOff
    ad = @ad
    meLoc = 0
    for leg in @legs
      debug 'getMoves:   meLoc=%o leg=%o', meLoc, leg
      meLoc += leg.gap
      legLen = leg.len
      youMdx = leg.youMdx
      if youMdx? and leg.youMdx > @mdx
        youModifier = ad.modifiers[youMdx]
        youModOff = meModOff + ad.getModOffDiff @mdx, youMdx
        debug 'getMoves:   meModOff=%o, youModOff=%o', meModOff, youModOff
        youLoc = youModifier.putMove leg.id
        debug 'getMoves:   meLoc=%o, youLoc=%o', meLoc, youLoc
        meIdx = @haveBegin + meModOff + meLoc
        youModifier = youModifier.haveBegin + youModOff + youLoc
        if legLen < 0
          cb meIdx, youModifier + legLen, -legLen
        else
          cb youModifier, meIdx, legLen
          meLoc += legLen
        @doneBalance += legLen
        leg.done = true
      else
        if legLen > 0
          if leg.done
            meLoc += legLen
        else if not leg.done
          meLoc -= legLen
    return


class ArrayDiff

  constructor: (@state, have, wish) ->
    @have = have
    @wish = wish
    @arrayDiffLimitGetter = @state.differ.arrayDiffLimitGetter
    @setupIdxers()
    @setupModifiers()
    if @modifiers.length > 0
      @setupLegs()

  setupIdxers: ->
    haveIdxer = new Idxer @state, @have
    wishIdxer = new Idxer @state, @wish, haveIdxer.allString
    if haveIdxer.allString and not wishIdxer.allString
      haveIdxer = new Idxer @state, @have, false
    # debug 'setupIdxers: have keys=%o allString=%o', haveIdxer.keys, haveIdxer.allString
    # debug 'setupIdxers: wish keys=%o allString=%o', wishIdxer.keys, wishIdxer.allString
    @haveIdxer = haveIdxer
    @wishIdxer = wishIdxer

  setupModifiers: ->
    haveIdxer = @haveIdxer
    wishIdxer = @wishIdxer

    modifiers = []
    wishKeyUses = {}

    ad = @
    scanCb = (haveBegin, haveEnd, wishBegin, wishEnd) ->
      debug 'setupModifiers: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd
      haveLen = haveEnd - haveBegin
      wishLen = wishEnd - wishBegin
      mdx = modifiers.length
      modifier = new Modifier ad, mdx, haveBegin, haveLen, wishBegin, wishLen
      modifiers.push modifier

      wishOfs = 0
      while wishOfs < wishLen
        wishKey = wishIdxer.keys[wishBegin + wishOfs]
        keyUse = wishKeyUses[wishKey]
        useTo = [mdx, wishOfs]
        if keyUse?
          keyUse.push useTo
        else
          wishKeyUses[wishKey] = [useTo]
        ++wishOfs

    diffLenLimit = @arrayDiffLimitGetter?(@wish)

    diffLen = mdiff(haveIdxer.keys, wishIdxer.keys).scanDiff scanCb, diffLenLimit
    @aborted = not diffLen?
    @modifiers = modifiers
    @wishKeyUses = wishKeyUses
    return

  setupLegs: ->
    # debug 'setupLegs: @wishKeyUses=%o', @wishKeyUses
    haveIdxer = @haveIdxer
    wishKeyUses = @wishKeyUses
    modifiers = @modifiers
    nextLegId = 0
    for modifier in modifiers
      haveBegin = modifier.haveBegin
      haveLen  = modifier.haveLen
      # debug 'setupLegs: modifier mdx=%o %o~%o', modifier.mdx, haveBegin, haveLen
      leg = null
      for haveOfs in [0...haveLen]
        key = haveIdxer.keys[haveBegin + haveOfs]
        wishKeyUse = wishKeyUses[key]
        # debug 'setupLegs:   key=%o wishKeyUse', key, wishKeyUse
        if wishKeyUse and wishKeyUse.length > 0
          [wishMdx, wishOfs] = wishKeyUse.pop()
          # debug 'setupLegs:   modifier mdx=%o leg=%o wishMdx=%o, haveOfs=%o, wishOfs=%o', modifier.mdx, leg, wishMdx, haveOfs, wishOfs
          if leg? and wishMdx == leg.wishMdx and haveOfs == leg.haveOfs + leg.len and wishOfs == leg.wishOfs + leg.len
            ++leg.len
            # debug 'setupLegs:   ..%o', leg
          else
            if leg?
              # debug 'setupLegs:   ->%o', leg
              modifiers[leg.haveMdx].addPreLeg leg
              modifiers[leg.wishMdx].addPreLeg leg
            leg =
              id: nextLegId++
              haveMdx: modifier.mdx
              haveOfs: haveOfs
              wishMdx: wishMdx
              wishOfs: wishOfs
              len: 1
      if leg?
        # debug 'setupLegs:   .->%o', leg
        modifiers[leg.haveMdx].addPreLeg leg
        modifiers[leg.wishMdx].addPreLeg leg
    @nextLegId = nextLegId
    # @debugModifiers 'setupLegs'
    for modifier in modifiers
      modifier.setupLegs()
    @debugModifiers 'setupLegs done.'
    return


  getModOffDiff: (fromMdx, toMdx) ->
    sum = 0
    modifiers = @modifiers
    if fromMdx < toMdx
      idx = fromMdx
      while idx < toMdx
        # debug 'getModOffDiff: idx=%o, +doneBalance=%o', idx, modifiers[idx]
        sum += modifiers[idx++].doneBalance
    else
      idx = toMdx
      while idx < fromMdx
        # debug 'getModOffDiff: idx=%o, -doneBalance=%o', idx, modifiers[idx]
        sum -= modifiers[idx++].doneBalance
    sum

  getDeleteDelta: ->
    delta = ''
    count = 0
    meModOff = @getModOffDiff 0, @modifiers.length
    for modifier in @modifiers by -1
      meModOff -= modifier.doneBalance
      modifier.getDeletes meModOff, (pos, len) ->
        debug 'getDeleteDelta: pos=%o, len=%o', pos, len
        delta += if count == 0 then '[-' else '|'
        delta += pos
        if len != 1
          delta += '~' + len
        ++count
    if count > 0
      delta += ']'

    # @debugModifiers 'getDeleteDelta done.'
    delta

  getInsertDelta: ->
    delta = ''
    count = 0
    meModOff = @getModOffDiff 0, @modifiers.length
    wishIdxer = @wishIdxer
    debug 'getInsertDelta: meModOff=%o', meModOff
    for modifier in @modifiers by -1
      meModOff -= modifier.doneBalance
      modifier.getInserts meModOff, (havePos, wishPos, len) ->
        debug 'getInsertDelta: havePos=%o, wishPos=%o, len=%o', havePos, wishPos, len
        delta += if count == 0 then '[+' else '|'
        delta += havePos
        for i in [0...len]
          delta += ':' + wishIdxer.getItem wishPos + i
        ++count
    if count > 0
      delta += ']'

    # @debugModifiers 'getInsertDelta done.'
    delta

  getPatchDelta: ->
    delta = ''
    count = 0
    meModOff = 0
    have = @have
    wish = @wish
    state = @state
    debug 'getPatchDelta: meModOff=%o', meModOff
    for modifier in @modifiers
      modifier.getPatches meModOff, (havePos, wishPos, len) ->
        debug 'getPatchDelta: havePos=%o, wishPos=%o, len=%o', havePos, wishPos, len
        delta += if count == 0 then '{' else '|'
        delta += havePos
        canChain = true
        for i in [0...len]
          iDelta = state.getDelta(
            have[havePos + i]
            wish[wishPos + i]
          )
          if iDelta[0] != ':'
            canChain = false
          if i > 0 and not canChain
            delta += '|' + (havePos + i)
          delta += iDelta
        ++count
      meModOff += modifier.doneBalance
    if count > 0
      delta += '}'
    delta


  getMoveDelta: ->
    delta = ''
    count = 0
    meModOff = 0
    for modifier in @modifiers
      modifier.getMoves meModOff, (srcPos, dstPos, len) ->
        debug 'getMoveDelta: srcPos=%o, dstPos=%o, len=%o', srcPos, dstPos, len
        delta += if count == 0 then '[!' else '|'
        delta += srcPos
        if len != 1
          delta += '~' + len
        delta += '@' + dstPos
        ++count
      meModOff += modifier.doneBalance
    if count > 0
      delta += ']'
    # @debugModifiers 'getMoveDelta done.'
    delta

  getDelta: ->
    if @modifiers.length == 0
      null
    else
      delta = ''
      delta += @getDeleteDelta()
      delta += @getMoveDelta()
      delta += @getInsertDelta()
      delta += @getPatchDelta()
      delta

  debugModifiers: (title) ->
    debug title + ' modifiers:'
    for modifier in @modifiers
      debug '  mdx=%o have=%o~%o wish=%o~%o, restBalance=%o', modifier.mdx, modifier.haveBegin, modifier.haveLen, modifier.wishBegin, modifier.wishLen, modifier.restBalance
      for leg in modifier.legs
        debug '    %o', leg
      debug '  closeGap=%o', modifier.closeGap


module.exports = ArrayDiff



