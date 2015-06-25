'use strict'

_ = require 'lodash'
debug = require('debug') 'wson-diff:patch'
wson = require 'wson'

class WsonDiffError extends Error
  constructor: ->
    if Error.captureStackTrace
      Error.captureStackTrace @, @constructor

class PrePatchError extends WsonDiffError
  name: 'PrePatchError'
  constructor: (@cause) ->

class PatchError extends WsonDiffError
  name: 'PatchError'
  constructor: (@s, @pos, @cause) ->
    super()
    if not @pos?
      @pos = @s.length
    if not @cause
      if @pos >= @s.length
        char = "end"
      else
        char = "'#{@s[@pos]}'"
      @cause = "unexpected #{char}"
    @message = "#{@cause} at '#{@s.slice 0, @pos}^#{@s.slice @pos}'"


class WsonDiff

  constructor: ->
    @WSON = wson(useAddon: true)

  createPatcher: ->  
    new Patcher @


reIndex = /^\d+$/    

SCALAR = 1
OBJECT = 2
ARRAY  = 3


class Target

  constructor: (up, key) ->
    @up = up
    @key = key
    if up?
      @value = up[key]
    @_type = null
    debug 'Target %o', @

  reset: (source) ->
    @up = source.up
    @key = source.key
    @value = source.value
    @_type = source._type

  getType: ->
    type = @_type
    if not type?
      value = @value
      @_type = type = if _.isArray value
        ARRAY
      else if _.isObject value
        OBJECT
      else
        SCALAR
    type    

  enterPath: (key) ->
    type = @getType()
    debug 'enterPath value=%o type=%o, key=%o', @value, type, key
    if type == SCALAR
      throw new PrePatchError "can't index scalar #{@value}"
    if type == ARRAY
      if not reIndex.test key
        throw new PrePatchError "non-numeric index #{key} for array #{@value}"
      key = Number key
    @up = @up[@key]
    @value = @up[key]
    @key = key  
    @_type = null
    return

  setValue: (value) ->
    debug 'setValue @up=%o, @key=%o value=%o', @up, @key, value
    @up[@key] = @value = value
    @type = null
    debug 'setValue ok'
    return


class State

  constructor: (@str, @baseTarget, @stage, @parent) ->
    @target = new Target()
    @resetPath()
    debug 'State %o', @ 

  resetPath: ->
    @target.reset @baseTarget

  push: (stage, rawNext) ->
    state = new State @str, @target, stage, @
    state.rawNext = rawNext
    state

  pop: (stage, rawNext) ->
    if not @parent?
      throw new PrePatchError()
    @parent

  startScope: ->
    @stage = stages.scopeHas
    @push stages.pathBegin, true

  startModify: ->
    c = @str[++@pos]
    debug 'startModify c=%o', c
    switch c
      when '-'
        @stage = stages.deleteNext
      else 
        throw new PrePatchError()
    @rawNext = true
    @skipNext = 1
    @

stages = 
  pathBegin: 
    value: (value) ->
      @target.enterPath value
      @stage = stages.pathHas
      @
    '#': (value) ->
      @target.enterPath ''
      @stage = stages.pathHas
      @
    '|': ->
      @stage = stages.pathNext
      @
    ':': ->
      @stage = stages.scopeAssign
      @
    '{': ->
      @startScope()
    '[': ->
      @startModify()
    '}': ->
      @pop()
  pathNext: 
    value: (value) ->
      @target.enterPath value
      @stage = stages.pathHas
      @
    '#': (value) ->
      @target.enterPath ''
      @stage = stages.pathHas
      @
    '{': ->
      @startScope()
    '[': ->
      @startModify()
  pathHas: 
    '|': ->
      @stage = stages.pathNext
      @
    ':': ->
      @stage = stages.scopeAssign
      @
    '{': ->
      @startScope()
    '[': ->
      @startModify()
  scopeAssign: 
    value: (value) ->
      @target.setValue value
      @stage = stages.scopeHas
      @
  scopeHas: 
    '|': ->
      @resetPath()
      @stage = stages.pathBegin
      @
    '{': ->
      @startScope()
    '[': (value, prevPos, nextPos) ->
      @startModify nextPos
    '}': ->
      @pop()
    end: ->
      if @parent?
        throw new PrePatchError()
  deleteNext:
    ']': ->
      @stage = stages.scopeHas
      @


do ->
  for name, stage of stages
    stage.name = name


class Patcher

  constructor: (@wsonDiff) ->

  patch: (target, str) ->
    debug 'patch: target=%o, str=%o', target, str
    try
      if str[0] != '|'
        return @wsonDiff.WSON.parse str

      target = new Target _: target, '_'
      state = new State str, target, stages.pathNext
      state.pos = 1
     
      @wsonDiff.WSON.parsePartial str, [true, 1], (isValue, value, nextPos) ->
        stage = state.stage
        debug 'patch: stage=%o, isValue=%o, value=%o, nextPos=%o', stage.name, isValue, value, nextPos
        if isValue
          handler = stage.value
        else
          handler = stage[value]
        if not handler  
          handler = stage.default
        if not handler  
          throw new PatchError str, state.pos
        debug 'patch: handler=%o', handler
        state.rawNext = true
        state.skipNext = 0
        state = handler.call state, value, nextPos
        debug 'patch: rawNext=%o, skipNext=%o, stage=%o', state.rawNext, state.skipNext, state.stage.name
        state.pos = nextPos
        if state.skipNext > 0
          state.pos += state.skipNext
          return [state.rawNext, state.skipNext]
        else  
          return state.rawNext
        
      debug 'patch: done: stage=%o', state.stage.name
      state.pos = str.length
      handler = state.stage.end
      if not handler  
        throw new PatchError str
      handler.call state

      return target.up._

    catch error
      if error instanceof PrePatchError
        throw new PatchError str, state.pos, error.cause
      else if error instanceof wson.ParseError
        throw new PatchError error.s, error.pos, error.cause
      else
        throw error
        # throw new PatchError str, state.pos, error


factory = (options) ->
  new WsonDiff options

factory.PatchError = PatchError  

module.exports = factory









