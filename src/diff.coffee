_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'

errors = require './errors'


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
