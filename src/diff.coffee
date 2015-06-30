_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'
mdiff = require 'mdiff'

errors = require './errors'
Idxer = require './idxer'


class Transposer

  constructor: (@tdx, @haveBegin, @haveLen, @wishBegin, @wishLen) ->
    @moves = []
    @moveSum = 0
    @adjust = 0    # of inserts - # of deletes

  addMove: (move) ->
    @moves.push move
    @moveSum += move.len

  prepareMoves: ->
    @moves.sort (m1, m2) ->
      if m1.miOfs < m2.miOfs
        -1
      else if m1.miOfs > m2.miOfs
        +1
      else if m1.len < m2.len
        -1
      else
        +1

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

  putMove: (yuTdx, yuMove) ->
    debug 'putMove: yuTdx=%o, yuMove=%o %o', yuTdx, yuMove, # @
    shift = 0
    for miMove in @moves
      if miMove.yuTdx?
        after =
          if miMove.miOfs > yuMove.yuOfs
            true
          else if miMove.miOfs < yuMove.yuOfs
            false
          else if miMove.len < 100
            true
          else
            false
        if after
          debug 'putMove: miMove=%o, after=%o', miMove, after
          continue
        done =
          if miMove.yuTdx < yuTdx
            true
          else if miMove.yuTdx > yuTdx
            false
          else if miMove.yuOfs < yuMove.miOfs
            true
          else if miMove.yuOfs > yuMove.miOfs
            false
          else if miMove.len < yuMove.len
            true
          else
            false
        debug 'putMove: miMove=%o, done=%o', miMove, done
        if done
        else
          if miMove.len > 0
            shift -= miMove.len
          if miMove.len < 0
            shift -= miMove.len

    @adjust -= yuMove.len
    debug 'putMove: shift=%o', shift
    yuMove.yuOfs + shift


  getMoves: (ad, miOff, cb) ->
    thisShift = 0
    for move in @moves
      moveLen = move.len
      debug 'getMoves: move=%o thisShift=%o', move, thisShift
      if move.yuTdx?
        # real move
        if move.yuTdx > @tdx
          # todo
          yuOff = miOff + ad.getOffDiff @tdx, move.yuTdx
          debug 'getMoves: miOff=%o, yuOff=%o', miOff, yuOff
          yuTransposer = ad.transposers[move.yuTdx]
          yuOfs = yuTransposer.putMove @tdx, move
          miIdx = @haveBegin + move.miOfs + miOff + thisShift
          yuIdx = yuTransposer.haveBegin + yuOfs + yuOff
          if moveLen > 0
            cb yuIdx, miIdx, moveLen
          else
            cb miIdx, yuIdx + moveLen, -moveLen
          @adjust += moveLen
      thisShift += moveLen
    miOff + @adjust


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
      tdx = transposers.length
      transposer = new Transposer tdx, haveBegin, haveLen, wishBegin, wishLen
      transposers.push transposer

      wishOfs = 0
      while wishOfs < wishLen
        wishKey = wishIdxer.keys[wishBegin + wishOfs]
        keyUse = wishKeyUses[wishKey]
        useTo = [tdx, wishOfs]
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
          dstTransposer = transposers[dstTdx]
          moveLen = 1
          srcTransposer.addMove
            miOfs: srcOfs
            yuTdx: dstTdx
            yuOfs: dstOfs
            len:   -moveLen
          dstTransposer.addMove
            miOfs: dstOfs
            yuTdx: srcTdx
            yuOfs: srcOfs
            len:   moveLen
        ++srcOfs
    for transposer in transposers
      transposer.prepareMoves()
    debug 'setupMoves:'
    for transposer in transposers
       debug '  %o', transposer

  getOffDiff: (fromTdx, toTdx) ->
    sum = 0
    transposers = @transposers
    if fromTdx < toTdx
      idx = fromTdx
      while idx < toTdx
        debug 'getOffDiff: idx=%o, +adjust=%o', idx, transposers[idx]
        sum += transposers[idx++].adjust
    else
      idx = toTdx
      while idx < fromTdx
        debug 'getOffDiff: idx=%o, -adjust=%o', idx, transposers[idx]
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
    miOff = 0
    for transposer in @transposers
      debug 'getMoveDelta: %o', transposer
      miOff = transposer.getMoves @, miOff, (srcIdx, dstIdx, moveLen) ->
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
