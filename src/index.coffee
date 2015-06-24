'use strict'

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


class State

  constructor: (@str, @baseUp, @baseKey, @stage, @parent) ->
    @resetPath()

  resetPath: ->
    @up  = @baseUp
    @key = @baseKey

  enterPath: (key) ->  
    @up = @up[@key]
    @key = key  

  push: (stage, howNext) ->
    state = new State @str, @up, @key, stage, @
    state.howNext = howNext
    state

  pop: (stage, howNext) ->
    if not @parent?
      throw new PrePatchError()
    @parent

  setValue: (value) ->
    debug 'setValue @up=%o, @key=%o value=%o', @up, @key, value
    @up[@key] = value
    debug 'setValue ok'
    return


stages = 
  pathBegin: 
    value: (value) ->
      @enterPath value
      @stage = stages.pathHas
      @
    '|': ->
      @stage = stages.pathNext
      @
    ':': ->
      @stage = stages.scopeAssign
      @
  pathNext: 
    value: (value) ->
      @enterPath value
      @stage = stages.pathHas
      @
  pathHas: 
    '|': ->
      @stage = stages.pathNext
      @
    ':': ->
      @stage = stages.scopeAssign
      @
    '{': ->
      @stage = stages.scopeHas
      @push stages.pathBegin, true
  scopeAssign: 
    value: (value) ->
      @setValue value
      @stage = stages.scopeHas
      @
  scopeHas: 
    '|': ->
      @resetPath()
      @stage = stages.pathBegin
      @
    '}': ->
      @pop()
    end: ->
      if @parent?
        throw new PrePatchError()


    # '{': ->
    #   @stage = stages.scopeNext
    #   @
    # ':': ->
    #   @stage = stages.setTarget
    #   @howNext = 're'
    #   @
  # scopeNext:
  #   value: -> 
  #     @stage = stages.pathNext
  #     @howNext = 're'
  #     @
  #   '}': ->
  #     @stage = stages.scopeEnd
  #     @
  # scopeEnd: {}


  # end: {}

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

      up = _: target 

      state = new State str, up, '_', stages.pathNext
      prevPos = 1
      howNext = [true, 1]
     
      @wsonDiff.WSON.parsePartial str, howNext, (isValue, value, nextPos) ->
        stage = state.stage
        debug 'patch: stage=%o, isValue=%o, value=%o, nextPos=%o', stage.name, isValue, value, nextPos
        if isValue
          handler = stage.value
        else
          handler = stage[value]
        if not handler  
          handler = stage.default
        if not handler  
          throw new PatchError str, prevPos
        debug 'patch: handler=%o', handler
        state.howNext = true
        state = handler.call state, value, prevPos, nextPos
        prevPos = nextPos
        debug 'patch: howNext=%o, stage=%o', state.howNext, state.stage.name
        return state.howNext
        
      debug 'patch: done: stage=%o', state.stage.name
      prevPos = str.length
      handler = state.stage.end
      if not handler  
        throw new PatchError str
      handler.call state

      return up._

    catch error
      if error instanceof PrePatchError
        throw new PatchError str, prevPos, error.cause
      else if error instanceof wson.ParseError
        throw new PatchError error.s, error.pos, error.cause
      else
        throw new PatchError str, prevPos, error


factory = (options) ->
  new WsonDiff options

factory.PatchError = PatchError  

module.exports = factory









