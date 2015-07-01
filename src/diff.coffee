_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'
mdiff = require 'mdiff'

errors = require './errors'
Idxer = require './idxer'


class Modifier

  constructor: (@mdx, @haveBegin, @haveLen, @wishBegin, @wishLen) ->
    @rawLegs = []
    @adjust = 0    # of inserts - # of deletes

  addRawLeg: (leg) ->
    @rawLegs.push leg

  setupLegs: ->
    mdx = @mdx
    outLegs = _(@rawLegs).filter((leg) -> leg.srcMdx == mdx).sortBy('srcOfs').value()
    inLegs = _(@rawLegs).filter((leg) -> leg.dstMdx == mdx).sortBy('dstOfs').value()
    debug 'setupLegs: mdx=%o, outLegs=%o, inLegs=%o', mdx, outLegs, inLegs
    legs = []
    outLastEnd = 0
    inLastEnd = 0
   
    haveLen = @haveLen
    wishLen = @wishLen
    outVdx = 0
    inVdx = 0
    outLegIdx = 0
    inLegIdx = 0

    nextOut = ->
      if outLegIdx < outLegs.length
        outLeg = outLegs[outLegIdx++]
        outVdx += outLeg.srcOfs - outLastEnd
        outLastEnd = outLeg.srcOfs + outLeg.len
        outLeg
      else
        outVdx += haveLen - outLastEnd
        null

    nextIn = ->
      if inLegIdx < inLegs.length
        inLeg = inLegs[inLegIdx++]
        inVdx += inLeg.dstOfs - inLastEnd
        inLastEnd = inLeg.dstOfs + inLeg.len
        inLeg
      else
        inVdx += wishLen - inLastEnd
        null

    outLeg = nextOut()
    inLeg = nextIn()

    rr = 16
    loop
      debug 'setupLegs:   outVdx=%o, inVdx=%o, outLeg=%o, inLeg=%o', outVdx, inVdx, outLeg, inLeg
      if outVdx < inVdx or (outVdx == inVdx and not inLeg?)
        if outLeg?
          outLeg.srcVdx = outVdx
          legs.push outLeg
          outLeg = nextOut()
        else
          # debug 'setupLegs:   insert'
          legs.push
            dstMdx: @mdx
            dstVdx: outVdx 
            len: inVdx - outVdx
          outVdx = inVdx
      else    
        if inLeg?
          inLeg.dstVdx = inVdx
          legs.push inLeg
          inLeg = nextIn()
        else  
          # debug 'setupLegs:   delete'
          legs.push
            srcMdx: @mdx
            srcVdx: inVdx 
            len: outVdx - inVdx
          inVdx = outVdx
      if not inLeg? and not outLeg? and outVdx == inVdx   
        break
      if --rr == 0
        break

    # debug 'setupLegs: mdx=%o, legs=%o', mdx, legs
    @rawLegs = null
    @legs = legs
        

  getDeletes: (cb) ->
    delRest = @haveLen - @wishLen + @moveSum
    debug 'getDeletes: delRest=%o', delRest
    delEnd = @haveLen
    moves = @moves
    moveIdx = moves.length
    rr = 16
    insMoveOfs = null
    while delRest > 0
      if --rr <= 0
        break
      --moveIdx
      if moveIdx >= 0
        move = moves[moveIdx]
        if move.len > 0
          insMoveOfs = move.miOfs
          continue
        delBegin = move.miOfs - move.len
      else
        delBegin = 0
      debug 'getDeletes: %o..%o', delBegin, delEnd
      delLen = delEnd - delBegin
      if delLen > 0
        if delLen > delRest
          delLen = delRest
          delBegin = delEnd - delLen
        cb @haveBegin + delBegin, delLen
        # moves.splice moveIdx + (if insMoveOfs == move.miOfs then 2 else 1), 0,
        #   miOfs: delBegin
        #   len: -delLen
        delRest -= delLen
      if moveIdx >= 0
        delEnd = move.miOfs
      @adjust -= delLen

  putMove: (leg) ->
    debug 'putMove: leg=%o', leg
    legLen = leg.len
    isOut = leg.srcMdx == @mdx
    yuMdx = if isOut then leg.dstMdx else leg.srcMdx
    isUp = leg.dstMdx > leg.srcMdx
    miLoc = 0
    if isOut
      @adjust -= legLen
    else
      @adjust += legLen
    debug 'putMove: miLoc=%o', miLoc
    miLoc


  getMoves: (ad, miModOff, cb) ->
    thisShift = 0
    miVdx = 0
    miLoc = 0
    for leg in @legs
      legLen = leg.len
      isOut = leg.srcMdx == @mdx
      yuMdx = if isOut then leg.dstMdx else leg.srcMdx
      if yuMdx?
        isUp = leg.dstMdx > leg.srcMdx
        debug 'getMoves: isUp=%o, isOut=%o leg=%o thisShift=%o', isUp, isOut, leg, thisShift
        if isUp == isOut
          yuModifier = ad.modifiers[yuMdx]
          yuModOff = miModOff + ad.getModOffDiff @mdx, yuMdx
          debug 'getMoves: miModOff=%o, yuModOff=%o', miModOff, yuModOff
          yuLoc = yuModifier.putMove leg
          miIdx = @haveBegin + miLoc + miModOff + thisShift
          yuIdx = yuModifier.haveBegin + yuLoc + yuModOff
          if isUp
            cb miIdx, yuIdx - legLen, legLen
            @adjust -= legLen
          else  
            cb yuIdx, miIdx, legLen
            @adjust += legLen
        else    
    miModOff + @adjust


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

    d = mdiff(haveIdxer.keys, wishIdxer.keys).scanDiff (haveBegin, haveEnd, wishBegin, wishEnd) ->
      debug 'setupModifiers: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd
      haveLen = haveEnd - haveBegin
      wishLen = wishEnd - wishBegin
      mdx = modifiers.length
      modifier = new Modifier mdx, haveBegin, haveLen, wishBegin, wishLen
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
    # debug 'setupModifiers: d=%o', d
    # for modifier in modifiers
    #    debug '  %o', modifier
    # debug '  wishKeyUses=%o', wishKeyUses
    @modifiers = modifiers
    @wishKeyUses = wishKeyUses

  setupLegs: ->
    haveIdxer = @haveIdxer
    wishKeyUses = @wishKeyUses
    modifiers = @modifiers
    for srcModifier, srcMdx in modifiers
      srcBegin = srcModifier.haveBegin
      srcLen   = srcModifier.haveLen
      srcOfs = 0
      leg = null
      while srcOfs < srcLen
        key = haveIdxer.keys[srcBegin + srcOfs]
        keyUse = wishKeyUses[key]
        if keyUse and keyUse.length > 0
          [dstMdx, dstOfs] = keyUse.pop()
          dstModifier = modifiers[dstMdx]
          if leg? and dstMdx == leg.dstMdx and srcOfs == leg.srcOfs + leg.len and dstOfs == leg.dstOfs + leg.len 
            ++leg.len 
          else 
            if leg?
              srcModifier.addRawLeg leg
              dstModifier.addRawLeg leg
            leg =
              srcMdx: srcMdx
              srcOfs: srcOfs
              dstMdx: dstMdx
              dstOfs: dstOfs
              len: 1
        ++srcOfs
      if leg?  
        srcModifier.addRawLeg leg
        dstModifier.addRawLeg leg
    for modifier in modifiers
      modifier.setupLegs()
    debug 'setupLegs:'
    for modifier in modifiers
       debug '  mdx=%o', modifier.mdx
       for leg in modifier.legs
         debug '    %o', leg

  getModOffDiff: (fromMdx, toMdx) ->
    sum = 0
    modifiers = @modifiers
    if fromMdx < toMdx
      idx = fromMdx
      while idx < toMdx
        # debug 'getModOffDiff: idx=%o, +adjust=%o', idx, modifiers[idx]
        sum += modifiers[idx++].adjust
    else
      idx = toMdx
      while idx < fromMdx
        # debug 'getModOffDiff: idx=%o, -adjust=%o', idx, modifiers[idx]
        sum -= modifiers[idx++].adjust
    sum

  getDeleteDelta: ->
    delta = ''
    count = 0
    for modifier in @modifiers by -1
      debug 'getDeleteDelta: modifier=%o', modifier
      modifier.getDeletes (delIdx, delLen) ->
        debug 'getDeleteDelta: delIdx=%o, delLen=%o', delIdx, delLen
        delta += if count == 0 then '[-' else '|'
        delta += delIdx
        if delLen != 1
          delta += '~' + delLen
        ++count
    if count > 0
      delta += ']'

    debug 'getDeleteDelta:'
    for modifier in @modifiers
       debug '  %o', modifier
    delta

  getMoveDelta: ->
    delta = ''
    count = 0
    miModOff = 0
    for modifier in @modifiers
      debug 'getMoveDelta: mdx=%o', modifier.mdx
      miModOff = modifier.getMoves @, miModOff, (srcIdx, dstIdx, moveLen) ->
        debug 'getMoveDelta: srcIdx=%o, dstIdx=%o, moveLen=%o', srcIdx, dstIdx, moveLen
        delta += if count == 0 then '[!' else '|'
        delta += srcIdx
        if moveLen != 1
          delta += '~' + moveLen
        delta += '@' + dstIdx
        ++count
    if count > 0
      delta += ']'

    # debug 'getMoveDelta:'
    # for modifier in @modifiers
    #    debug '  %o', modifier
    delta

  getDelta: ->
    if @modifiers.length == 0
      null
    else
      delta = ''
      # delta += @getDeleteDelta()
      # @getMoveDelta()
      delta += @getMoveDelta()
      delta


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
