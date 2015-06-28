_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'
mdiff = require 'mdiff'

errors = require './errors'
Idxer = require './idxer'


class DiffChunk

  constructor: (@srcB, @srcE, @dstB, @dstE) ->
    @srcMoves = []
    @dstMoves = []
    @shifts = []
    @shiftSum = 0

  putSrcMove: (move) ->
    @srcMoves.push move
    # @corrOfs move.srcOfs, 1
    @shifts.push move.srcOfs
    @shifts.push 1

  putDstMove: (dstOfs) ->
    # @corrOfs dstOfs, -1
    @dstMoves.push dstOfs

  corrOfs: (ofs, len) ->
    debug 'corrOfs: ofs=%o len=%o @shiftSum=%o @shifts=%o', ofs, len, @shiftSum, @shifts
    shifts = @shifts
    i = shifts.length
    shiftSum = @shiftSum
    loop
      if i <= 1
        shifts.splice.call shifts, 0, 0, ofs, len
        break
      else  
        shiftLen = shifts[--i]
        shiftOfs = shifts[--i]
        if shiftOfs < ofs
          if len != 0
            shifts.splice.call shifts, i + 2, 0, ofs, len
          break
        if shiftOfs == ofs
          shifts[i+1] += len
          if len > 0
            shiftSum -= shiftLen
          break
        shiftSum -= shiftLen
    @shiftSum += len
    ofs += shiftSum
    debug 'corrOfs: ofs=%o @shiftSum=%o @shifts=%o', ofs, @shiftSum, @shifts
    ofs

  withDeletes: (cb) ->
    srcLen = @srcE - @srcB
    dstLen = @dstE - @dstB
    delRest = srcLen - dstLen - @srcMoves.length + @dstMoves.length
    debug 'withDeletes: delRest=%o', delRest
    delE = srcLen
    moves = @srcMoves
    moveIdx = moves.length
    while delRest > 0
      if moveIdx > 0
        move = moves[--moveIdx]
        delB = move.srcOfs + 1
      else
        delB = 0
      debug 'withDeletes: delB=%o, delE=%o', delB, delE
      delLen = delE - delB
      if delLen > delRest
        delLen = delRest
        delB = delE - delLen
      cb @srcB + @corrOfs(delB, -delLen), delLen
      delRest -= delLen
      delE = delB - 1
        
  withMoves: (chunks, srcChunkIdx, srcShiftSum, cb) ->
    for move in @srcMoves
      dstChunkIdx = move.dstChunkIdx
      dstShiftSum = srcShiftSum
      if srcChunkIdx < dstChunkIdx
        idx = srcChunkIdx
        while idx < dstChunkIdx
          dstShiftSum += chunks[idx++].shiftSum
      else    
        idx = dstChunkIdx
        while idx < srcChunkIdx
          dstShiftSum += chunks[idx++].shiftSum
      dstChunk = chunks[dstChunkIdx]    
      debug 'withMoves: srcChunkIdx=%o move=%o srcShiftSum=%o, dstShiftSum=%o', srcChunkIdx, move, srcShiftSum, dstShiftSum
      debug 'withMoves: srcChunk=%o', @
      debug 'withMoves: dstChunk=%o', dstChunk
      srcOfs = @corrOfs(move.srcOfs, -1)
      dstOfs = dstChunk.corrOfs(move.dstOfs, 1)
      debug 'withMoves: srcOfs=%o dstOfs=%o', srcOfs, dstOfs
      srcIdx = srcShiftSum + @srcB + srcOfs
      dstIdx = dstShiftSum + dstChunk.srcB + dstOfs
      if srcIdx < dstIdx
        --dstIdx
      cb srcIdx, dstIdx, 1


class State
  
  constructor: (@wsonDiff) ->

  getPlainDelta: (src, dst, isRoot) ->
    WSON = @wsonDiff.WSON
    delta = WSON.stringify dst
    if not isRoot
      delta = ':' + delta
    delta  

  getObjectDelta: (src, dst, isRoot) ->
    WSON = @wsonDiff.WSON
    delta = ''
    debug 'getObjectDelta(src=%o, dst=%o, isRoot=%o)', src, dst, isRoot

    delDelta = ''
    delCount = 0
    srcKeys = _(src).keys().sort().value()
    for key in srcKeys
      if not _.has dst, key
        if delCount > 0
          delDelta += '|'
        delDelta += WSON.stringify key
        ++delCount
    if delCount > 0
      delta += '[-' + delDelta + ']'

    subDelta = ''
    subCount = 0
    dstKeys = _(dst).keys().sort().value()
    for key in dstKeys
      keyDelta = @getDelta src[key], dst[key]
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

  getArrayDelta: (src, dst, isRoot) ->
    allString = true
    srcIdxer = new Idxer @wsonDiff, src
    dstIdxer = new Idxer @wsonDiff, dst, srcIdxer.allString
    if srcIdxer.allString and not dstIdxer.allString
      srcIdxer = new Idxer @wsonDiff, src, false
    debug 'getArrayDelta: src keys=%o allString=%o', srcIdxer.keys, srcIdxer.allString
    debug 'getArrayDelta: dst keys=%o allString=%o', dstIdxer.keys, dstIdxer.allString
    chunks = []
    dstKeyUses = {}
    d = mdiff(src, dst).scanDiff (srcB, srcE, dstB, dstE) ->
      debug 'getArrayDelta: %o..%o %o..%o', srcB, srcE, dstB, dstE
      chunk = new DiffChunk srcB, srcE, dstB, dstE
      chunks.push chunk
      dstIdx = dstB
      while dstIdx < dstE
        dstKey = dstIdxer.keys[dstIdx]
        keyUse = dstKeyUses[dstKey]
        useCi = [chunks.length - 1, dstIdx]
        if keyUse?
          keyUse.push useCi
        else
          dstKeyUses[dstKey] = [useCi]
        ++dstIdx
    debug 'getArrayDelta: dstKeyUses=%o', dstKeyUses
    for srcChunk in chunks
      srcIdx = srcChunk.srcB
      while srcIdx < srcChunk.srcE
        srcKey = srcIdxer.keys[srcIdx]
        dstKeyUse = dstKeyUses[srcKey]
        if dstKeyUse and dstKeyUse.length > 0
          [dstChunkIdx, dstIdx] = dstKeyUse.pop()
          debug 'getArrayDelta: move srcIdx=%o dstChunkIdx=%o dstIdx=%o', srcIdx, dstChunkIdx, dstIdx
          dstChunk = chunks[dstChunkIdx]
          srcOfs = srcIdx - srcChunk.srcB
          dstOfs = dstIdx - dstChunk.dstB
          srcChunk.putSrcMove srcOfs: srcOfs, dstChunkIdx: dstChunkIdx, dstOfs: dstOfs
          dstChunk.putDstMove dstOfs
        ++srcIdx

    delta = ''

    delDeltaCount = 0
    for chunk in chunks by -1
      debug 'getArrayDelta: chunk=%o', chunk
      chunk.withDeletes (delIdx, delLen) ->
        debug 'getArrayDelta: delIdx=%o, delLen=%o', delIdx, delLen
        if delDeltaCount == 0
          delta += '[-'
        else 
          delta += '|'
        delta += delIdx
        if delLen != 1  
          delta += '~' + delLen
        ++delDeltaCount  
    if delDeltaCount > 0
      delta += ']'

    moveDeltaCount = 0
    shiftSum = 0
    for chunk, chunkIdx in chunks
      chunk.withMoves chunks, chunkIdx, shiftSum, (srcIdx, dstIdx, moveLen) ->
        debug 'getArrayDelta: srcIdx=%o, dstIdx=%o, moveLen=%o', srcIdx, dstIdx, moveLen
        if moveDeltaCount == 0
          delta += '[!'
        else 
          delta += '|'
        delta += srcIdx
        if moveLen != 1  
          delta += '~' + moveLen
        delta += '@' + dstIdx
        ++moveDeltaCount  
      shiftSum += chunk.shiftSum
    if moveDeltaCount > 0
      delta += ']'

    if isRoot
      delta = '|' + delta
    return delta
    return @getPlainDelta src, dst, isRoot


  getDelta: (src, dst, isRoot) ->
    if _.isArray src
      if _.isArray dst
        return @getArrayDelta src, dst, isRoot
      else
        return @getPlainDelta src, dst, isRoot
    else if _.isObject src
      if not _.isArray(dst) and _.isObject(dst)
        return @getObjectDelta src, dst, isRoot
      else
        return @getPlainDelta src, dst, isRoot
    else #scalar src
      if src != dst
        return @getPlainDelta src, dst, isRoot
    null  


class Differ

  constructor: (@wsonDiff) ->

  diff: (src, dst) ->
    state = new State @wsonDiff
    state.getDelta src, dst, true


exports.Differ = Differ
exports.DiffChunk = DiffChunk
