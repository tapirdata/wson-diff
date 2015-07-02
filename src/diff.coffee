_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'
mdiff = require 'mdiff'

errors = require './errors'
Idxer = require './idxer'


class Modifier

  constructor: (@ad, @mdx, @haveBegin, @haveLen, @wishBegin, @wishLen) ->
    @legs = []
    @doneBalance = 0    # of inserts - # of deletes already performed
    @insertBalance = 0   # if > 0: extra inserts, if < 0: extra deletes

  addPreLeg: (leg) ->
    @legs.push leg

  setupLegs: ->
    mdx = @mdx
    outLegs = _(@legs).filter((leg) -> leg.srcMdx == mdx).sortBy('srcBeg').value()
    inLegs = _(@legs).filter((leg) -> leg.dstMdx == mdx).sortBy('dstBeg').value()
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
        outGapSum += outLeg.srcBeg - outEnd
        outEnd = outLeg.srcBeg + outLeg.len
        outLeg
      else
        outGapSum += haveLen - outEnd
        null

    nextInLeg = ->
      if inLegIdx < inLegs.length
        inLeg = inLegs[inLegIdx++]
        inGapSum += inLeg.dstBeg - inEnd
        inEnd = inLeg.dstBeg + inLeg.len
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
      debug 'setupLegs:   gapSum=%o outGapSum=%o inGapSum=%o outLeg=%o inLeg=%o', gapSum, outGapSum, inGapSum, outLeg, inLeg
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
            @gapSum = gapSum
            break
          else
            extraLen = inLater

      if extraLen < 0
        # delete 
        legs.push
          gap: inGapSum - gapSum
          len: extraLen
          done: false
        gapSum = inGapSum
        outGapSum = gapSum
        @insertBalance += inLater
      else if extraLen > 0
        # insert 
        legs.push
          gap: outGapSum - gapSum
          len: extraLen
          done: false
        gapSum = outGapSum
        inGapSum = gapSum
        @insertBalance += inLater
      if takeOut
        legs.push
          gap: outGapSum - gapSum
          len: -outLeg.len
          id: outLeg.id
          yuMdx: outLeg.dstMdx
          done: false
        gapSum = outGapSum
        outLeg = nextOutLeg()
      if takeIn
        legs.push
          gap: inGapSum - gapSum
          len: inLeg.len
          id: inLeg.id
          yuMdx: inLeg.srcMdx
          done: false
        gapSum = inGapSum
        inLeg = nextInLeg()
      if --rr == 0
        break

    @legs = legs
        

  getDeletes: (cb) ->
    delRest = -@insertBalance
    if delRest <= 0
      return
    delEndLoc = @haveLen
    for leg in @legs by -1
      debug 'getDeletes: delRest=%o delEndLoc=%o leg=%o', delRest, delEndLoc, leg
      legLen = leg.len
      if leg.yuMdx? or legLen > 0
        delEndLoc -= leg.gap
        # debug 'getDeletes: * delEndLoc=%o', delEndLoc, leg.done, legLen > 0
        if leg.done == (legLen > 0)
          delEndLoc += legLen
          # debug 'getDeletes: ** delEndLoc=%o', delEndLoc
      else
        if legLen < 0
          delBegLoc = delEndLoc + legLen
          cb @haveBegin + delBegLoc, -legLen
          delEndLoc = delBegLoc - leg.gap
          @doneBalance += legLen
          leg.done = true
          delRest += legLen
          if delRest == 0
            break
    return null      

  putMove: (legId) ->
    debug 'putMove: legId=%o', legId
    for leg in @legs
      if leg.id == legId
        @doneBalance += leg.len
        leg.done = true  
        return 0


  getMoves: (miModOff, cb) ->
    ad = @ad
    miLoc = 0
    for leg in @legs
      legLen = leg.len
      yuMdx = leg.yuMdx
      if yuMdx?
        debug 'getMoves: leg=%o', leg
        if leg.yuMdx > @mdx
          yuModifier = ad.modifiers[yuMdx]
          yuModOff = miModOff + ad.getModOffDiff @mdx, yuMdx
          debug 'getMoves: miModOff=%o, yuModOff=%o', miModOff, yuModOff
          yuLoc = yuModifier.putMove leg.id
          debug 'getMoves: miLoc=%o, yuLoc=%o', miLoc, yuLoc
          miIdx = @haveBegin + miLoc + miModOff
          yuIdx = yuModifier.haveBegin + yuLoc + yuModOff
          if legLen < 0
            cb miIdx, yuIdx + legLen, -legLen
            @doneBalance += legLen
          else  
            cb yuIdx, miIdx, legLen
            @doneBalance += legLen
          leg.done = true  
        else    
    miModOff + @doneBalance


class ArrayDiff

  constructor: (@wsonDiff, have, wish) ->
    @have = have
    @wish = wish
    @setupIdxers()
    @setupModifiers()
    if @modifiers.length > 0
      @setupLegs()

  setupIdxers: ->
    haveIdxer = new Idxer @wsonDiff, @have
    wishIdxer = new Idxer @wsonDiff, @wish, haveIdxer.allString
    if haveIdxer.allString and not wishIdxer.allString
      haveIdxer = new Idxer @wsonDiff, @have, false
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
    d = mdiff(haveIdxer.keys, wishIdxer.keys).scanDiff (haveBegin, haveEnd, wishBegin, wishEnd) ->
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
    @modifiers = modifiers
    @wishKeyUses = wishKeyUses

  setupLegs: ->
    haveIdxer = @haveIdxer
    wishKeyUses = @wishKeyUses
    modifiers = @modifiers
    for srcModifier, srcMdx in modifiers
      srcBegin = srcModifier.haveBegin
      srcLen   = srcModifier.haveLen
      srcBeg = 0
      leg = null
      legId = 0
      while srcBeg < srcLen
        key = haveIdxer.keys[srcBegin + srcBeg]
        keyUse = wishKeyUses[key]
        if keyUse and keyUse.length > 0
          [dstMdx, dstBeg] = keyUse.pop()
          dstModifier = modifiers[dstMdx]
          if leg? and dstMdx == leg.dstMdx and srcBeg == leg.srcBeg + leg.len and dstBeg == leg.dstBeg + leg.len 
            ++leg.len 
          else 
            if leg?
              srcModifier.addPreLeg leg
              dstModifier.addPreLeg leg
            leg =
              id: legId++
              srcMdx: srcMdx
              srcBeg: srcBeg
              dstMdx: dstMdx
              dstBeg: dstBeg
              len: 1
        ++srcBeg
      if leg?  
        srcModifier.addPreLeg leg
        dstModifier.addPreLeg leg
    for modifier in modifiers
      modifier.setupLegs()
    @debugModifiers 'setupLegs done.'


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
    for modifier in @modifiers by -1
      modifier.getDeletes (delIdx, delLen) ->
        debug 'getDeleteDelta: delIdx=%o, delLen=%o', delIdx, delLen
        delta += if count == 0 then '[-' else '|'
        delta += delIdx
        if delLen != 1
          delta += '~' + delLen
        ++count
    if count > 0
      delta += ']'

    @debugModifiers 'getDeleteDelta done.' 
    delta    

  getMoveDelta: ->
    delta = ''
    count = 0
    miModOff = 0
    for modifier in @modifiers
      debug 'getMoveDelta: mdx=%o', modifier.mdx
      miModOff = modifier.getMoves miModOff, (srcIdx, dstIdx, moveLen) ->
        debug 'getMoveDelta: srcIdx=%o, dstIdx=%o, moveLen=%o', srcIdx, dstIdx, moveLen
        delta += if count == 0 then '[!' else '|'
        delta += srcIdx
        if moveLen != 1
          delta += '~' + moveLen
        delta += '@' + dstIdx
        ++count
    if count > 0
      delta += ']'
    @debugModifiers 'getMoveDelta done.' 
    delta

  getDelta: ->
    if @modifiers.length == 0
      null
    else
      delta = ''
      delta += @getDeleteDelta()
      delta += @getMoveDelta()
      delta
     
  debugModifiers: (title) ->
    debug title + ' modifiers:'
    for modifier in @modifiers
      debug '  mdx=%o insertBalance=%o', modifier.mdx, modifier.insertBalance
      for leg in modifier.legs
        debug '    %o', leg


class State

  constructor: (@wsonDiff) ->

  getPlainDelta: (have, wish, isRoot) ->
    WSON = @wsonDiff.WSON
    delta = WSON.stringify wish
    if not isRoot
      delta = ':' + delta
    delta

  getObjectDelta: (have, wish, isRoot) ->
    WSON = @wsonDiff.WSON
    delta = ''
    debug 'getObjectDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot

    delDelta = ''
    delCount = 0
    haveKeys = _(have).keys().sort().value()
    for key in haveKeys
      if not _.has wish, key
        if delCount > 0
          delDelta += '|'
        delDelta += WSON.stringify key
        ++delCount
    if delCount > 0
      delta += '[-' + delDelta + ']'

    subDelta = ''
    subCount = 0
    wishKeys = _(wish).keys().sort().value()
    for key in wishKeys
      keyDelta = @getDelta have[key], wish[key]
      debug 'getObjectDelta: key=%o, keyDelta=%o', key, keyDelta
      if keyDelta?
        if subCount > 0
          subDelta += '|'
        subDelta += WSON.stringify(key) + keyDelta
        ++subCount
    debug 'getObjectDelta: subDelta=%o, subCount=%o', subDelta, subCount
    if subCount > 0
      if not isRoot
        if subCount > 1
          subDelta = '{' + subDelta + '}'
        else if delCount == 0
          subDelta = '|' + subDelta
      delta += subDelta
    if delta.length
      if isRoot
        delta = '|' + delta
      return delta
    null

  getArrayDelta: (have, wish, isRoot) ->
    ad = new ArrayDiff @wsonDiff, have, wish
    delta = ad.getDelta()
    if delta?
      if isRoot
        delta = '|' + delta
    delta


  getDelta: (have, wish, isRoot) ->
    if _.isArray have
      if _.isArray wish
        return @getArrayDelta have, wish, isRoot
      else
        return @getPlainDelta have, wish, isRoot
    else if _.isObject have
      if not _.isArray(wish) and _.isObject(wish)
        return @getObjectDelta have, wish, isRoot
      else
        return @getPlainDelta have, wish, isRoot
    else #scalar have
      if have != wish
        return @getPlainDelta have, wish, isRoot
    null


class Differ

  constructor: (@wsonDiff) ->

  diff: (src, dst) ->
    state = new State @wsonDiff
    state.getDelta src, dst, true


exports.Differ = Differ
exports.Modifier = Modifier
