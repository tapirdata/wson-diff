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
reRange = /^(\d+)(\+(\d+))?$/
reMove = /^(\d+)([+|-](\d+))?@(\d+)$/
reSubst = /^(\d+)(\+(\d+))?(=(.+))?$/

SCALAR = 1
STRING = 2
OBJECT = 3
ARRAY  = 4


class State

  constructor: (@delta, @pos, @target, parent) ->
    @stage = null
    @parent = parent
    @scopeType = @currentType = if parent then parent.getCurrentType() else null
    @pendingSteps = 0
    @pendingKey = null
    @haveSteps = 0
    @reHandle = false

  getCurrentType: ->
    type = @currentType
    if not type?
      value = @target.get 0
      type = if _.isArray value
        ARRAY
      else if _.isObject value
        OBJECT
      else if _.isString value
        STRING
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

  budgePendingKey: ->
    if @pendingKey?
      @target.budge @pendingSteps, @pendingKey
      @pendingSteps = 0
      ++@haveSteps
      @currentType = null
      @pendingKey = null
    return

  enterObjectKey: (key) ->
    @budgePendingKey()
    debug 'enterObjectKey key=%o', key
    type = @getCurrentType()
    if type != OBJECT
      if type == ARRAY
        throw new PrePatchError "can't index array #{@target.get()} with object index #{key}"
      else
        throw new PrePatchError "can't index scalar #{@target.get()}"
    @pendingKey = key
    return

  enterArrayKey: (skey) ->
    @budgePendingKey()
    debug 'enterArrayKey skey=%o', skey
    type = @getCurrentType()
    if not reIndex.test skey
      throw new PrePatchError "non-numeric array index #{skey} for #{@target.get()}"
    key = Number skey
    if type != ARRAY
      if type == OBJECT
        throw new PrePatchError "can't index object #{@target.get()} with array index #{key}"
      else
        throw new PrePatchError "can't index scalar #{@target.get()}"
    @pendingKey = key
    return

  resetPath: ->
    @pendingSteps = @haveSteps
    @haveSteps = 0
    @currentType = @scopeType
    @pendingKey = null
    return

  pushState: ->
    @budgePendingKey()
    debug 'pushState stage=%o', @stage?.name
    new State @delta, @pos, @target, @

  popState: ->
    if not @stage.canPop
      throw new PrePatchError()
    if not @parent?
      throw new PrePatchError()
    debug 'popState @haveSteps=%o', @haveSteps
    @parent.haveSteps += @haveSteps
    @parent.pos = @pos
    @parent

  assignValue: (value) ->
    @budgePendingSteps()
    try
      @target.assign @pendingKey, value
    catch e  
      throw PrePatchError e
    @assignValues = null
    return

  startReplace: () ->
    @replaceValues = []

  addReplace: (value) ->
    @replaceValues.push value

  commitReplace: ->
    debug 'commitReplace pendingKey=%o replaceValues=%o', @pendingKey, @replaceValues
    if @replaceValues?
      @budgePendingSteps()
      @target.replace @pendingKey, @replaceValues
      @replaceValues = null
    return

  doUnset: (key) ->
    debug 'doUnset key=%o', key
    @budgePendingKey()
    @target.unset key
    return

  doDelete: (skey) ->
    debug 'doDelete skey=%o', skey
    @budgePendingKey()
    m = reRange.exec skey
    if not m?
      throw new PrePatchError "ill-formed range '#{skey}'"
    key = Number m[1]
    len = if m[3]? then Number(m[3]) + 1 else 1
    @target.delete key, len
    return

  continueModify: ->
    c = @delta[++@pos]
    type = @getCurrentType()
    debug 'coninueModify c=%o', c
    switch c
      when '='
        expectedType = OBJECT
        stage = stages.assignBegin
      when '-'
        expectedType = OBJECT
        stage = stages.unsetBegin
      when 'd'
        expectedType = ARRAY
        stage = stages.deleteBegin
      when 'i'
        expectedType = ARRAY
        stage = stages.insertBegin
      when 'm'
        expectedType = ARRAY
        stage = stages.moveBegin
      when 'r'
        expectedType = ARRAY
        stage = stages.replaceBegin
      when 's'
        expectedType = STRING
        stage = stages.substituteBegin
      else
        throw new PrePatchError()
    if type != expectedType
      if expectedType == ARRAY
        throw new PatchError @delta, @pos, "can't patch #{@target.get()} with array modifier"
      else  
        throw new PatchError @delta, @pos, "can't patch #{@target.get()} with object modifier"
    @stage = stage
    @rawNext = true
    @skipNext = 1
    @

  startModify: ->
    debug 'startModify'
    state = @pushState()
    state.continueModify()
    state

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

  doMove: (skey) ->
    debug 'doMove skey=%o', skey
    m = reMove.exec skey
    if not m?
      throw new PrePatchError "ill-formed move '#{skey}'"
    srcKey = Number m[1]
    if m[3]?
      len = Number(m[3]) + 1
      reverse = m[2][0] == '-'
    else
      len = 1
      reverse = false
    dstKey = Number m[4]

    debug 'doMove srcKey=%o dstKey=%o len=%o reverse=%o', srcKey, dstKey, len, reverse
    @target.move srcKey, dstKey, len, reverse
    return

  startSubstitute: (skey) ->
    @substituteValues = []
    @addSubstitute skey
    return

  addSubstitute: (skey) ->
    m = reSubst.exec skey
    if not m? 
      throw new PrePatchError "invalid substitution #{skey} for string #{@target.get()}"
    ofs = Number m[1]
    if m[3]?
      len = Number(m[3]) + 1
    else
      len = 0
    if m[5]?
      str = m[5]
    else  
      str = ''
    @substituteValues.push [ofs, len, str]

  commitSubstitute: ->
    debug 'commitSubstitute insertValues=%o', @substituteValues
    @target.substitute @substituteValues
    return


stages =
  assignBegin:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      @
    '#': (value) ->
      @enterObjectKey ''
      @stage = stages.assignHasKey
      @
  assignHasKey:
    '|': ->
      @stage = stages.assignBegin
      @
    ':': ->
      @rawNext = false
      @stage = stages.assignHasColon
      @
    '[': ->
      @stage = stages.assignHasModify
      @startModify()
  assignHasColon:
    value: (value) ->
      @assignValue value
      @stage = stages.assignHasValue
      @
  assignHasValue:
    '|': ->
      @resetPath()
      @stage = stages.assignBegin
      @
    ']': ->
      if not @parent?
        throw new PrePatchError()
      @resetPath()
      @stage = stages.modifyEnd
      @
    end: ->
      if @parent?
        throw new PrePatchError()
  assignHasModify:
    '|': ->
      @resetPath()
      @stage = stages.assignBegin
      @
    ']': ->
      if not @parent?
        throw new PrePatchError()
      @resetPath()
      @stage = stages.modifyEnd
      @
    end: ->
      if @parent?
        throw new PrePatchError()

  replaceBegin:
    value: (value) ->
      @enterArrayKey value
      @stage = stages.replaceHasKey
      @
  replaceNextKey:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.replaceHasKey
      @
  replaceHasKey:
    '|': ->
      @stage = stages.replaceNextKey
      @
    ':': ->
      @rawNext = false
      @stage = stages.replaceHasColon
      @startReplace()
      @
    '[': ->
      @stage = stages.replaceHasModify
      @startModify()
  replaceHasColon:
    value: (value) ->
      @addReplace value
      @stage = stages.replaceHasValue
      @
  replaceHasValue:
    ':': ->
      @rawNext = false
      @stage = stages.replaceHasColon
      @
    '|': ->
      @commitReplace()
      @resetPath()
      @stage = stages.replaceBegin
      @
    ']': ->
      @commitReplace()
      @stage = stages.modifyEnd
      @
  replaceHasModify:
    '|': ->
      @commitReplace()
      @stage = stages.replaceBegin
      @
    ']': ->
      @commitReplace()
      @stage = stages.modifyEnd
      @

  unsetBegin:
    value: (value) ->
      @doUnset value
      @stage = stages.unsetHas
      @
    '#': ->
      @doUnset ''
      @stage = stages.unsetHas
      @
  unsetHas:
    ']': ->
      @stage = stages.modifyEnd
      @
    '|': ->
      @stage = stages.unsetBegin
      @

  deleteBegin:
    value: (value) ->
      @doDelete value
      @stage = stages.deleteHas
      @
    '#': ->
      @doDelete ''
      @stage = stages.deleteHas
      @
  deleteHas:
    ']': ->
      @stage = stages.modifyEnd
      @
    '|': ->
      @stage = stages.deleteBegin
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
      @stage = stages.modifyEnd
      @

  moveBegin:
    value: (value) ->
      @doMove value
      @stage = stages.moveHas
      @
  moveHas:
    ']': ->
      @stage = stages.modifyEnd
      @
    '|': ->
      @stage = stages.moveBegin
      @

  substituteBegin:
    value: (value) ->
      @startSubstitute value
      @stage = stages.substituteHas
      @
  substituteHas:
    ']': ->
      @commitSubstitute()
      @stage = stages.modifyEnd
      @
    '|': ->
      @stage = stages.substituteNext
      @
  substituteNext:
    value: (value) ->
      @addSubstitute value
      @stage = stages.substituteHas
      @


  modifyEnd:
    canPop: true
    '[': ->
      @continueModify()

  patchBegin:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      @
    '#': (value) ->
      @enterObjectKey ''
      @stage = stages.assignHasKey
      @
    '[': ->
      @stage = stages.patchHasModify
      @startModify()

  patchHasModify:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      @
    '#': (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      @
    end: ->
      if @parent?
        throw new PrePatchError()

do ->
  for name, stage of stages
    stage.name = name


class Patcher

  constructor: (@wsonDiff, options) ->

  patchTarget: (target, delta) ->
    debug 'patch: target=%o, delta=%o', target, delta
    try
      if delta[0] != '|'
        value = @wsonDiff.WSON.parse delta
        target.assign null, value
        return

      state = new State delta, 1, target, null
      state.stage = stages.patchBegin

      @wsonDiff.WSON.parsePartial delta,
        howNext: [true, 1]
        cb: (isValue, value, nextPos) ->
          loop
            stage = state.stage
            debug 'patch: stage=%o, isValue=%o, value=%o, nextPos=%o', stage.name, isValue, value, nextPos
            if isValue
              handler = stage.value
            else
              handler = stage[value]
            debug 'patch: handler=%o', handler
            if handler
              break
            state = state.popState()
          state.rawNext = true
          state.skipNext = 0
          state = handler.call state, value, nextPos
          debug 'patch: pos=%o, rawNext=%o, skipNext=%o, stage.name=%o', state.pos, state.rawNext, state.skipNext, state.stage?.name
          state.pos = nextPos
          if state.skipNext > 0
            state.pos += state.skipNext
            return [state.rawNext, state.skipNext]
          else
            return state.rawNext
        backrefCb: (refIdx) -> target.get refIdx

      debug 'patch: done: stage=%o', state.stage.name
      state.pos = delta.length
      loop
        handler = state.stage.end
        if handler
          break
        state = state.popState()
      handler.call state
      return

    catch error
      if error instanceof PrePatchError
        throw new PatchError delta, state.pos, error.cause
      else if error instanceof wson.ParseError
        throw new PatchError error.s, error.pos, error.cause
      else
        throw error

  patch: (value, delta) ->
    target = new ValueTarget value
    @patchTarget target, delta
    target.getRoot()


exports.Patcher = Patcher
exports.PatchError = PatchError









