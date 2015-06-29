_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'
mdiff = require 'mdiff'

errors = require './errors'
Idxer = require './idxer'


class Transposer

  constructor: (@haveBegin, @haveLen, @wishBegin, @wishLen) ->
    @srcMoves = []
    @dstMoves = []
    @srcMoveSum = 0
    @dstMoveSum = 0
    @adjust = 0    # of inserts - # of deletes

  putSrcMove: (move) ->
    @srcMoves.push move
    @srcMoveSum += move.len

  putDstMove: (move) ->
    dstMoves = @dstMoves
    for dstMove, moveIdx in dstMoves
      if dstMove.dstOfs > move.dstOfs
        break
    dstMoves.splice moveIdx, 0, move 
    @dstMoveSum += move.len

  getDeletes: (cb) ->
    delRest = @haveLen - @wishLen - @srcMoveSum + @dstMoveSum
    debug 'getDeletes: delRest=%o', delRest
    delEnd = @haveLen
    moves = @srcMoves
    moveIdx = moves.length
    while delRest > 0
      --moveIdx  
      if moveIdx >= 0
        move = moves[moveIdx]
        delBegin = move.srcOfs + 1
      else
        delBegin = 0
      debug 'getDeletes: %o..%o', delBegin, delEnd
      delLen = delEnd - delBegin
      if delLen > 0
        if delLen > delRest
          delLen = delRest
          delBegin = delEnd - delLen
        cb @haveBegin + delBegin, delLen
        @srcMoves.splice moveIdx + 1, 0,
          srcOfs: delBegin
          len: delLen
        delRest -= delLen
      delEnd = delBegin - 1
      @adjust -= delLen

  putMove: (dstOfs, len) ->
    debug 'putMove: %o', @
    shift = 0
    for move in @srcMoves
      if move.srcOfs > dstOfs
        break
      shift += move.len
    for move in @dstMoves
      if move.dstOfs == dstOfs
        move.len = 0
        break
      shift -= move.len
    @adjust += len
    debug 'putMove: dstOfs=%o len=%o, shift=%o', dstOfs, len, shift
    dstOfs + shift

  getMoves: (ad, srcTdx, srcOff, cb) ->
    thisShift = 0
    dstMoves = @dstMoves
    dstMoveLen = dstMoves.length
    dstMoveIdx = 0
    for move in @srcMoves
      while dstMoveIdx < dstMoveLen
        dstMove = dstMoves[dstMoveIdx]
        if dstMove.dstOfs >= move.srcOfs
          break
        thisShift += dstMove.len
        ++dstMoveIdx
      dstTdx = move.dstTdx
      moveLen = move.len
      debug 'getMoves: move=%o thisShift=%o', move, thisShift
      if dstTdx?
        dstOff = srcOff + ad.getOffDiff srcTdx, dstTdx
        debug 'getMoves: srcOff=%o, dstOff=%o', srcOff, dstOff
        dstTransposer = ad.transposers[move.dstTdx]
        dstOfs = dstTransposer.putMove move.dstOfs, moveLen
        srcIdx = @haveBegin + move.srcOfs + srcOff + thisShift
        dstIdx = dstTransposer.haveBegin + dstOfs + dstOff
        if dstIdx > srcIdx
          dstIdx -= moveLen
        else  
          srcOff += moveLen
        cb srcIdx, dstIdx, moveLen
        move.len = 0
        @adjust -= moveLen
      thisShift -= moveLen
    srcOff + @adjust  


class ArrayDiff

  constructor: (@wsonDiff, have, wish) ->
    @have = have
    @wish = wish
    @setupIdxers()
    @setupTransposers()
    if @transposers.length > 0
      @setupMoves()

  setupIdxers: ->  
    haveIdxer = new Idxer @wsonDiff, @have
    wishIdxer = new Idxer @wsonDiff, @wish, haveIdxer.allString
    if haveIdxer.allString and not wishIdxer.allString
      haveIdxer = new Idxer @wsonDiff, @have, false
    # debug 'setupIdxers: have keys=%o allString=%o', haveIdxer.keys, haveIdxer.allString
    # debug 'setupIdxers: wish keys=%o allString=%o', wishIdxer.keys, wishIdxer.allString
    @haveIdxer = haveIdxer
    @wishIdxer = wishIdxer

  setupTransposers: ->  
    haveIdxer = @haveIdxer
    wishIdxer = @wishIdxer

    transposers = []
    wishKeyUses = {}

    d = mdiff(haveIdxer.keys, wishIdxer.keys).scanDiff (haveBegin, haveEnd, wishBegin, wishEnd) ->
      debug 'setupTransposers: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd
      haveLen = haveEnd - haveBegin
      wishLen = wishEnd - wishBegin
      transposer = new Transposer haveBegin, haveLen, wishBegin, wishLen
      wishTdx = transposers.length
      transposers.push transposer

      wishOfs = 0
      while wishOfs < wishLen
        wishKey = wishIdxer.keys[wishBegin + wishOfs]
        keyUse = wishKeyUses[wishKey]
        useTo = [wishTdx, wishOfs]
        if keyUse?
          keyUse.push useTo
        else
          wishKeyUses[wishKey] = [useTo]
        ++wishOfs
    # debug 'setupTransposers: d=%o', d
    # for transposer in transposers
    #    debug '  %o', transposer
    # debug '  wishKeyUses=%o', wishKeyUses
    @transposers = transposers
    @wishKeyUses = wishKeyUses

  setupMoves: ->  
    haveIdxer = @haveIdxer
    wishKeyUses = @wishKeyUses
    transposers = @transposers
    for srcTransposer, srcTdx in transposers
      srcBegin = srcTransposer.haveBegin
      srcLen   = srcTransposer.haveLen
      srcOfs = 0
      while srcOfs < srcLen
        key = haveIdxer.keys[srcBegin + srcOfs]
        keyUse = wishKeyUses[key]
        if keyUse and keyUse.length > 0
          [dstTdx, dstOfs] = keyUse.pop()
          # debug 'setupMoves: move srcOfs=%o dstTdx=%o dstOfs=%o', srcOfs, dstTdx, dstOfs
          dstTransposer = transposers[dstTdx]
          move =
            srcTdx: srcTdx
            srcOfs: srcOfs
            dstTdx: dstTdx
            dstOfs: dstOfs
            len: 1
          srcTransposer.putSrcMove move
          dstTransposer.putDstMove move
        ++srcOfs
    # debug 'setupMoves:'
    # for transposer in transposers
    #    debug '  %o', transposer
  
  getOffDiff: (fromTdx, toTdx) ->
    sum = 0
    transposers = @transposers
    if fromTdx < toTdx
      idx = fromTdx
      while idx < toTdx
        sum += transposers[idx++].adjust
    else    
      idx = toTdx
      while idx < fromTdx
        sum -= transposers[idx++].adjust
    sum    
       
  getDeleteDelta: ->
    delta = ''
    count = 0
    for transposer in @transposers by -1
      debug 'getDeleteDelta: transposer=%o', transposer
      transposer.getDeletes (delIdx, delLen) ->
        debug 'getDeleteDelta: delIdx=%o, delLen=%o', delIdx, delLen
        delta += if count == 0 then '[-' else '|'
        delta += delIdx
        if delLen != 1  
          delta += '~' + delLen
        ++count  
    if count > 0
      delta += ']'

    debug 'getDeleteDelta:'
    for transposer in @transposers
       debug '  %o', transposer
    delta  

  getMoveDelta: ->
    delta = ''
    count = 0
    srcOff = 0
    for transposer, srcTdx in @transposers
      debug 'getMoveDelta: %o', transposer
      srcOff = transposer.getMoves @, srcTdx, srcOff, (srcIdx, dstIdx, moveLen) ->
        debug 'getMoveDelta: srcIdx=%o, dstIdx=%o, moveLen=%o', srcIdx, dstIdx, moveLen
        delta += if count == 0 then '[!' else '|'
        delta += srcIdx
        if moveLen != 1  
          delta += '~' + moveLen
        delta += '@' + dstIdx
        ++count  
    if count > 0
      delta += ']'

    debug 'getMoveDelta:'
    for transposer in @transposers
       debug '  %o', transposer
    delta  

  getDelta: ->
    if @transposers.length == 0
      null
    else  
      delta = ''
      delta += @getDeleteDelta()
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
exports.Transposer = Transposer
