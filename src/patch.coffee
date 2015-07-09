_ = require 'lodash'
debug = require('debug') 'wson-diff:patch'
wson = require 'wson'

errors = require './errors'
ValueTarget = require './value-target'

class PrePatchError extends errors.WsonDiffError
  name: 'PrePatchError'
  constructor: (@cause) ->


class PatchError extends errors.WsonDiffError
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


reIndex = /^\d+$/
reRange = /^(\d+)(~(\d+))?$/
reMove = /^(\d+)(~(\d+))?@(\d+)$/

SCALAR = 1
OBJECT = 2
ARRAY  = 3


class State

  constructor: (@str, @target, @stage, parent) ->
    @parent = parent
    @nextKey = null
    @scopeType = @currentType = if parent then parent.getCurrentType() else null
    @pendingSteps = 0
    @haveSteps = 0
    # debug 'State %o', @

  getCurrentType: ->
    type = @currentType
    if not type?
      value = @target.get 0
      type = if _.isArray value
        ARRAY
      else if _.isObject value
        OBJECT
      else
        SCALAR
      @currentType = type  
      if @haveSteps == 0
        @scopeType = type
    type

  budgePendingSteps: ->
    if @pendingSteps > 0
      @target.budge @pendingSteps
      @pendingSteps = 0

  budgeNextKey: ->
    if @nextKey?
      @target.budge @pendingSteps, @nextKey
      @pendingSteps = 0
      ++@haveSteps
      @currentType = null
      @nextKey = null
    return  

  enterPath: (skey) ->
    @budgeNextKey()
    type = @getCurrentType()
    debug 'enterPath type=%o, skey=%o', type, skey
    switch type
      when ARRAY
        if not reIndex.test skey
          throw new PrePatchError "non-numeric index #{skey} for array #{@target.get()}"
        key = Number skey
      when OBJECT
        key = skey
      else
        throw new PrePatchError "can't index scalar #{@target.get()}"
    @nextKey = key
    return

  resetPath: ->
    @pendingSteps = @haveSteps
    @haveSteps = 0
    @currentType = @scopeType
    @nextKey = null
    return

  push: (stage, rawNext) ->
    @budgeNextKey()
    state = new State @str, @target, stage, @
    state.rawNext = rawNext
    state

  pop: (stage, rawNext) ->
    if not @parent?
      throw new PrePatchError()
    debug 'pop @haveSteps=%o @parent=%o', @haveSteps, @parent
    @parent.haveSteps += @haveSteps
    @parent

  startScope: ->
    @stage = stages.scopeHas
    @push stages.pathBegin, true

  startAssign: (value) ->
    @assignValues = [value]

  addAssign: (value) ->
    @assignValues.push value
    
  commitAssign: ->
    debug 'commitAssign nextKey=%o assignValues=%o', @nextKey, @assignValues
    if @assignValues?
      @budgePendingSteps()
      @target.assign @nextKey, @assignValues
      @assignValues = null
    return

  deleteKey: (skey) ->
    debug 'deleteKey skey=%o', skey
    @budgeNextKey()
    type = @getCurrentType()
    switch type
      when ARRAY
        m = reRange.exec skey
        if not m?
          throw new PrePatchError "ill-formed range '#{skey}'"
        key = Number m[1]
        len = if m[3]? then Number m[3] else 1
      when OBJECT
        key = skey
        len = 1
      else
        throw new PrePatchError "can't delete from scalar #{@target.get()}"
    @target.delete key, len
    return

  startModify: ->
    c = @str[++@pos]
    debug 'startModify c=%o', c
    @budgeNextKey()
    switch c
      when '-'
        @stage = stages.deleteBegin
      when '+'
        if @getCurrentType() != ARRAY
          throw new PrePatchError()
        @stage = stages.insertBegin
      when '!'
        if @getCurrentType() != ARRAY
          throw new PrePatchError()
        @stage = stages.moveBegin
      else
        throw new PrePatchError()
    @rawNext = true
    @skipNext = 1
    @

  startInsert: (skey) ->
    if not reIndex.test skey
      throw new PrePatchError "non-numeric index #{skey} for array #{@target.get()}"
    @insertKey = Number skey
    @insertValues = []
    return

  addInsert: (value) ->
    @insertValues.push value

  commitInsert: ->
    debug 'commitInsert insertKey=%o, insertValues=%o', @insertKey, @insertValues
    @target.insert @insertKey, @insertValues
    return

  moveKey: (skey) ->
    debug 'moveKey skey=%o', skey
    m = reMove.exec skey
    if not m?
      throw new PrePatchError "ill-formed move '#{skey}'"
    srcKey = Number m[1]
    len = if m[3]? then Number m[3] else 1
    dstKey = Number m[4]

    debug 'moveKey srcKey=%o, dstKey=%o, len=%o', srcKey, dstKey, len
    @target.move srcKey, dstKey, len
    return


stages =
  pathBegin:
    value: (value) ->
      @enterPath value
      @stage = stages.pathHas
      @
    '#': (value) ->
      @enterPath ''
      @stage = stages.pathHas
      @
    ':': ->
      @rawNext = false
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
      @enterPath value
      @stage = stages.pathHas
      @
    '#': (value) ->
      @enterPath ''
      @stage = stages.pathHas
      @
  pathHas:
    '|': ->
      @stage = stages.pathNext
      @
    ':': ->
      @rawNext = false
      @stage = stages.scopeAssign
      @
    '{': ->
      @startScope()
    '[': ->
      @startModify()
  scopeAssign:
    value: (value) ->
      @startAssign value
      @stage = stages.scopeHas
      @
  scopeAssignNext:
    value: (value) ->
      @addAssign value
      @stage = stages.scopeHas
      @
  scopeHas:
    value: (value) ->
      @commitAssign()
      @enterPath value
      @stage = stages.pathHas
      @
    '#': (value) ->
      @commitAssign()
      @enterPath ''
      @stage = stages.pathHas
      @
    ':': ->
      if @getCurrentType() != ARRAY
        throw new PrePatchError()
      @rawNext = false
      @stage = stages.scopeAssignNext
      @
    '|': ->
      @commitAssign()
      @resetPath()
      @stage = stages.pathBegin
      @
    '{': ->
      @commitAssign()
      @startScope()
    '[': ->
      @commitAssign()
      @startModify()
    '}': ->
      @commitAssign()
      @pop()
    end: ->
      @commitAssign()
      if @parent?
        throw new PrePatchError()
  deleteBegin:
    value: (value) ->
      @deleteKey value
      @stage = stages.deleteHas
      @
    '#': ->
      @deleteKey ''
      @stage = stages.deleteHas
      @
  deleteHas:
    ']': ->
      @stage = stages.scopeHas
      @
    '|': ->
      @stage = stages.deleteNext
      @
  deleteNext:
    value: (value) ->
      @deleteKey value
      @stage = stages.deleteHas
      @
    '#': ->
      @deleteKey ''
      @stage = stages.deleteHas
      @
  insertBegin:
    value: (value) ->
      @startInsert value
      @stage = stages.insertHasKey
      @
  insertHasKey:
    ':': ->
      @stage = stages.insertHasColon
      @rawNext = false
      @
  insertHasColon:
    value: (value) ->
      @addInsert value
      @stage = stages.insertHasValue
      @
  insertHasValue:
    ':': ->
      @stage = stages.insertHasColon
      @rawNext = false
      @
    '|': ->
      @commitInsert()
      @stage = stages.insertBegin
      @
    ']': ->
      @commitInsert()
      @stage = stages.scopeHas
      @
  moveBegin:
    value: (value) ->
      @moveKey value
      @stage = stages.moveHas
      @
  moveHas:
    ']': ->
      @stage = stages.scopeHas
      @
    '|': ->
      @stage = stages.moveNext
      @
  moveNext:
    value: (value) ->
      @moveKey value
      @stage = stages.moveHas
      @


do ->
  for name, stage of stages
    stage.name = name


class Patcher

  constructor: (@wsonDiff) ->

  patchTarget: (target, str) ->
    debug 'patch: target=%o, str=%o', target, str
    try
      if str[0] != '|'
        value = @wsonDiff.WSON.parse str
        target.assign null, [value]
        return

      state = new State str, target, stages.pathBegin
      state.pos = 1

      @wsonDiff.WSON.parsePartial str,
        howNext: [true, 1]
        cb: (isValue, value, nextPos) ->
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
        backrefCb: (refIdx) -> target.get refIdx

      debug 'patch: done: stage=%o', state.stage.name
      state.pos = str.length
      handler = state.stage.end
      if not handler
        throw new PatchError str
      handler.call state
      return

    catch error
      if error instanceof PrePatchError
        throw new PatchError str, state.pos, error.cause
      else if error instanceof wson.ParseError
        throw new PatchError error.s, error.pos, error.cause
      else
        throw error
        # throw new PatchError str, state.pos, error

  patch: (value, str) ->
    target = new ValueTarget value
    @patchTarget target, str
    target.getRoot()

exports.Patcher = Patcher
exports.PatchError = PatchError









