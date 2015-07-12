_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'

StringDiff = require './string-diff'
ObjectDiff = require './object-diff'
ArrayDiff = require './array-diff'

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
    diff = new StringDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getObjectDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    diff = new ObjectDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    @wishStack.pop()
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getArrayDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    diff = new ArrayDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    @wishStack.pop()
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getDelta: (have, wish, isRoot) ->
    if _.isArray have
      if _.isArray wish
        @getArrayDelta have, wish, isRoot
      else
        @getPlainDelta have, wish, isRoot
    else if _.isObject have
      if not _.isArray(wish) and _.isObject(wish)
        @getObjectDelta have, wish, isRoot
      else
        @getPlainDelta have, wish, isRoot
    else if _.isString have
      if _.isString wish
        @getStringDelta have, wish, isRoot
      else
        @getPlainDelta have, wish, isRoot
    else #scalar have
      if have == wish
        null
      else  
        @getPlainDelta have, wish, isRoot


class Differ

  constructor: (@wsonDiff, options) ->
    wdOptions = @wsonDiff.options
    options or= {}
    @stringEdge = if options.stringEdge?
      options.stringEdge
    else  
      wdOptions.stringEdge
    @stringLimit = if options.stringLimit?
      options.stringLimit
    else  
      wdOptions.stringLimit
    @arrayLimit = if options.arrayLimit?
      options.arrayLimit
    else  
      wdOptions.arrayLimit

  diff: (src, dst) ->
    state = new State @
    state.getDelta src, dst, true


exports.Differ = Differ
