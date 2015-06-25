_ = require 'lodash'
debug = require('debug') 'wson-diff:diff'

errors = require './errors'


class Delta


class PlainDelta extends Delta

   constructor: (@state, @dst) ->

   getStr: (forRoot) ->
     WSON = @state.wsonDiff.WSON
     WSON.stringify @dst


class ObjectDelta extends Delta

   constructor: (@state, @deltaCount, @keyDeltas, @delKeys) ->

   getStr: (forRoot) ->
     WSON = @state.wsonDiff.WSON
     str = ''
     if @deltaCount > 0
       deltaStrs = []
       for key, delta of @keyDeltas
         deltaStrs.push WSON.stringify(key) + ':' + delta.getStr()
       str += '{' + deltaStrs.join('|') + '}'  
     if @delKeys.length > 0
       delStrs = []
       for key in @delKeys
         delStrs.push WSON.stringify key
       str += '[-' + delStrs.join('|') + ']'  
     str  


class State
  
  constructor: (@wsonDiff) ->

  getObjectDelta: (src, dst) ->
    deltaCount = 0
    keyDeltas = {}
    for key, dstVal of dst
      delta = @getDelta src[key], dstVal
      if delta?
        ++deltaCount
        keyDeltas[key] = delta
    delKeys = []
    for key of src
      if not _.has dst, key
        delKeys.push key
    if deltaCount > 0 or delKeys.length > 0
      return new ObjectDelta @, deltaCount, keyDeltas, delKeys


  getArrayDelta: (src, dst) ->
    return new PlainDelta @, dst

  getDelta: (src, dst) ->
    if _.isArray src
      if _.isArray dst
        return @getArrayDelta src, dst
      else
        return new PlainDelta @, dst
    else if _.isObject src
      if _.isArray dst
        return new PlainDelta @, dst
      else if _.isObject dst
        return @getObjectDelta src, dst
    else #scalar src
      if src != dst
        return new PlainDelta @, dst


class Differ

  constructor: (@wsonDiff) ->

  diff: (src, dst) ->
    state = new State @wsonDiff
    delta = state.getDelta src, dst
    if delta?
      delta.getStr true


exports.Differ = Differ
