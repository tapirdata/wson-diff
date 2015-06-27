_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'
mdiff = require 'mdiff'

errors = require './errors'
Idxer = require './idxer'

class Move
  constructor: (@srcIdx, @dstIdx) ->


class DiffChunk

  constructor: (@srcB, @srcE, @dstB, @dstE) ->
    @srcMoves = []
    @dstMoves = []

  putSrcMove: (move) ->
    @srcMoves.push move

  putDstMove: (move) ->
    @dstMoves.push move

  withDeletes: (cb) ->
    delLenSum = 0
    delB = @srcB
    for srcMove in @srcMoves
      delE = srcMove.srcIdx
      delLen = delE - delB
      if delLen > 0
        cb delB - delLenSum, delLen
        delLenSum += delLen
      delB = delE + 1
    delE = @srcE
    delLen = delE - delB
    if delLen > 0
      cb delB - delLenSum, delLen
      delLenSum += delLen
    @delLenSum = delLenSum  

  withMoves: (cb) ->
    for srcMove in @srcMoves
      dstIdx = srcMove.dstIdx
      srcIdx = srcMove.srcIdx
      if dstIdx > srcIdx
        cb @srcB, dstIdx - 1

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
        useCi = [chunk, dstIdx]
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
          [dstChunk, dstIdx] = dstKeyUse.pop()
          debug 'getArrayDelta: move %o->%o', srcIdx, dstIdx
          move = new Move srcIdx, dstIdx
          srcChunk.putSrcMove move
          dstChunk.putDstMove move
        ++srcIdx

    delta = ''

    deleteCount = 0
    delLenSum = 0
    for chunk in chunks
      debug 'getArrayDelta: chunk=%o', chunk
      chunkDelLenSum = 0
      chunk.withDeletes (delIdx, delLen) ->
        debug 'getArrayDelta: delIdx=%o, delLen=%o', delIdx, delLen
        if deleteCount == 0
          delta += '[-'
        else 
          delta += '|'
        delta += delIdx - delLenSum
        if delLen != 1  
          delta += '~' + delLen
        ++deleteCount  
      delLenSum += chunk.delLenSum  
    if deleteCount > 0
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
