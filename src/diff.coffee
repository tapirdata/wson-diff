_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'

ArrayDiff = require './array-diff'
StringDiff = require './string-diff'

class State

  constructor: (@differ) ->
    @wishStack = []

  stringify: (val) ->
    debug 'stringify val=%o wishStack=%o', val, @wishStack
    wishStack = @wishStack
    @differ.wsonDiff.WSON.stringify val, haverefCb: (backVal) ->
      debug 'stringify:   backVal=%o', backVal
      for wish, idx in wishStack
        debug 'stringify:     wish=%o, idx=%o', wish, idx
        if wish == backVal
          debug 'stringify:   found.'
          return wishStack.length - idx - 1
      null

  getPlainDelta: (have, wish, isRoot) ->
    debug 'getPlainDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot
    delta = @stringify wish
    if not isRoot
      delta = ':' + delta
    delta

  getStringDelta: (have, wish, isRoot) ->
    sd = new StringDiff @, have, wish
    if not sd.aborted
      delta = sd.getDelta()
      if isRoot and delta?
        delta = '|' + delta
    @wishStack.pop()
    if sd.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getObjectDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    delta = ''
    debug 'getObjectDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot

    diffKeys = null
    if have.constructor? and have.constructor != Object
      connector = @differ.wsonDiff.WSON.connectorOfValue have
      diffKeys = connector?.diffKeys

    delta = ''
    delCount = 0
    haveKeys = diffKeys or _(have).keys().sort().value()
    for key in haveKeys
      if not _.has wish, key
        if delCount == 0
          if isRoot
            delta += '|'
          delta += '[-'
        else
          delta += '|'
        delta += @stringify key
        ++delCount
    if delCount > 0
      delta += ']'

    setDelta = ''
    setCount = 0
    wishKeys = diffKeys or _(wish).keys().sort().value()
    for key in wishKeys
      keyDelta = @getDelta have[key], wish[key]
      debug 'getObjectDelta: key=%o, keyDelta=%o', key, keyDelta
      if keyDelta?
        if setCount > 0
          setDelta += '|'
        setDelta += @stringify(key) + keyDelta
        ++setCount
    debug 'getObjectDelta: setDelta=%o, setCount=%o', setDelta, setCount
    if setCount > 0
      if isRoot
        if delCount == 0
          delta += '|'
        delta += setDelta
      else
        if setCount == 1 and delCount == 0
          delta += '|'
          delta += setDelta
        else
          delta += '[=' + setDelta + ']'
    @wishStack.pop()
    if delta.length
      return delta
    null

  getArrayDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    ad = new ArrayDiff @, have, wish
    if not ad.aborted
      delta = ad.getDelta()
      if isRoot and delta?
        delta = '|' + delta
    @wishStack.pop()
    if ad.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta


  getDelta: (have, wish, isRoot) ->
    if _.isArray have
      if _.isArray wish
        return @getArrayDelta have, wish, isRoot
      else
        return @getPlainDelta have, wish, isRoot
    else if _.isObject have
      if not _.isArray(wish) and _.isObject(wish) and have.constructor == wish.constructor
        return @getObjectDelta have, wish, isRoot
      else
        return @getPlainDelta have, wish, isRoot
    else if false and _.isString have
      if _.isString wish
        return @getStringDelta have, wish, isRoot
      else
        return @getPlainDelta have, wish, isRoot
    else #scalar have
      if have != wish
        return @getPlainDelta have, wish, isRoot
    null


class Differ

  constructor: (@wsonDiff, options) ->
    options or= {}
    @arrayDiffLimitGetter = options.arrayDiffLimitGetter or @wsonDiff.options.arrayDiffLimitGetter

  diff: (src, dst) ->
    state = new State @
    state.getDelta src, dst, true


exports.Differ = Differ
