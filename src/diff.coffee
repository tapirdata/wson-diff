_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'

ArrayDiff = require './array-diff'

class State

  constructor: (@wsonDiff) ->
    @wishStack = []

  stringify: (val) ->
    debug 'stringify val=%o wishStack=%o', val, @wishStack
    wishStack = @wishStack
    @wsonDiff.WSON.stringify val, haverefCb: (backVal) ->
      debug 'stringify:   backVal=%o', backVal
      for wish, idx in wishStack
        debug 'stringify:     wish=%o, idx=%o', wish, idx
        if wish == backVal
          debug 'stringify:   found.'
          return wishStack.length - idx - 1
      null

  getPlainDelta: (have, wish, isRoot) ->
    delta = @stringify wish
    if not isRoot
      delta = ':' + delta
    delta

  getObjectDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    delta = ''
    debug 'getObjectDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot

    delDelta = ''
    delCount = 0
    haveKeys = _(have).keys().sort().value()
    for key in haveKeys
      if not _.has wish, key
        if delCount > 0
          delDelta += '|'
        delDelta += @stringify key
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
        subDelta += @stringify(key) + keyDelta
        ++subCount
    debug 'getObjectDelta: subDelta=%o, subCount=%o', subDelta, subCount
    if subCount > 0
      if not isRoot
        if subCount > 1
          subDelta = '{' + subDelta + '}'
        else if delCount == 0
          subDelta = '|' + subDelta
      delta += subDelta
    @wishStack.pop()
    if delta.length
      if isRoot
        delta = '|' + delta
      return delta
    null

  getArrayDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    ad = new ArrayDiff @, have, wish
    delta = ad.getDelta()
    @wishStack.pop()
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
      if not _.isArray(wish) and _.isObject(wish) and have.constructor == wish.constructor
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
