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
reSubst = /^(\d+)([+|-](\d+))?(=(.+))?$/

TI_STRING = 20
TI_ARRAY  = 24
TI_OBJECT = 32


class State

  constructor: (@WSON, @delta, @pos, @target, @stage) ->
    @scopeTi = null
    @currentTi = null
    @pendingKey = null
    @pendingSteps = 0
    @targetDepth = 0
    @scopeDepth = 0
    @scopeStack  = []

  getCurrentTi: ->
    ti = @currentTi
    if not ti?
      value = @target.get 0
      ti = @WSON.getTypeid value
      @currentTi = ti
      if @haveSteps == 0
        @scopeTi = ti
    ti

  budgePending: (withKey) ->
    debug 'budgePending withKey=%o pendingSteps=%o pendingKey=%o', withKey, @pendingSteps, @pendingKey
    if withKey and @pendingKey?
      @target.budge @pendingSteps, @pendingKey
      @targetDepth -= @pendingSteps - 1
      @pendingSteps = 0
      @currentTi = null
      @pendingKey = null
    else if @pendingSteps > 0
      @target.budge @pendingSteps
      @targetDepth -= @pendingSteps
      @pendingSteps = 0
    return

  resetPath: ->
    debug 'resetPath targetDepth=%o scopeDepth=%o', @targetDepth, @scopeDepth
    @pendingSteps = @targetDepth - @scopeDepth
    @pendingKey = null
    @currentTi = @scopeTi
    return

  enterObjectKey: (key) ->
    @budgePending true
    debug 'enterObjectKey key=%o', key
    ti = @getCurrentTi()
    if ti != TI_OBJECT
      if ti == TI_ARRAY
        throw new PrePatchError "can't index array #{@target.get()} with object index #{key}"
      else
        throw new PrePatchError "can't index scalar #{@target.get()}"
    @pendingKey = key
    return

  enterArrayKey: (skey) ->
    @budgePending true
    debug 'enterArrayKey skey=%o', skey
    ti = @getCurrentTi()
    if not reIndex.test skey
      throw new PrePatchError "non-numeric array index #{skey} for #{@target.get()}"
    key = Number skey
    if ti != TI_ARRAY
      if ti == TI_OBJECT
        throw new PrePatchError "can't index object #{@target.get()} with array index #{key}"
      else
        throw new PrePatchError "can't index scalar #{@target.get()}"
    @pendingKey = key
    return

  pushScope: (nextStage) ->
    debug 'pushScope scopeDepth=%o @targetDepth=%o stage=%o', @scopeDepth, @targetDepth, @stage?.name
    @scopeStack.push [@scopeDepth, @scopeTi, nextStage]
    @scopeDepth = @targetDepth
    return

  popScope: ->
    if not @stage.canPop
      throw new PrePatchError()
    scopeStack = @scopeStack
    debug 'popScope scopeStack=%o', scopeStack
    if scopeStack.length == 0
      throw new PrePatchError()
    [@scopeDepth, @scopeTi, @stage] = scopeStack.pop()
    return

  assignValue: (value) ->
    @budgePending false
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
      @budgePending false
      @target.replace @pendingKey, @replaceValues
      @replaceValues = null
    return

  doUnset: (key) ->
    debug 'doUnset key=%o', key
    @budgePending false
    @target.unset key
    return

  doDelete: (skey) ->
    debug 'doDelete skey=%o', skey
    @budgePending true
    m = reRange.exec skey
    if not m?
      throw new PrePatchError "ill-formed range '#{skey}'"
    key = Number m[1]
    len = if m[3]? then Number(m[3]) + 1 else 1
    @target.delete key, len
    return

  continueModify: ->
    c = @delta[++@pos]
    ti = @getCurrentTi()
    debug 'coninueModify c=%o', c
    switch c
      when '='
        expectedTi = TI_OBJECT
        stage = stages.assignBegin
      when '-'
        expectedTi = TI_OBJECT
        stage = stages.unsetBegin
      when 'd'
        expectedTi = TI_ARRAY
        stage = stages.deleteBegin
      when 'i'
        expectedTi = TI_ARRAY
        stage = stages.insertBegin
      when 'm'
        expectedTi = TI_ARRAY
        stage = stages.moveBegin
      when 'r'
        expectedTi = TI_ARRAY
        stage = stages.replaceBegin
      when 's'
        expectedTi = TI_STRING
        stage = stages.substituteBegin
      else
        throw new PrePatchError()
    if ti != expectedTi
      if expectedTi == TI_ARRAY
        throw new PatchError @delta, @pos, "can't patch #{@target.get()} with array modifier"
      else
        throw new PatchError @delta, @pos, "can't patch #{@target.get()} with object modifier"
    @stage = stage
    @rawNext = true
    @skipNext = 1
    return

  startModify: (nextStage) ->
    debug 'startModify nextStage=%o', nextStage.name
    @budgePending true
    @pushScope nextStage
    @continueModify()
    return

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
      lenDiff = Number m[3]
      if m[2][0] == '-'
        lenDiff = -lenDiff
    else
      lenDiff = 0
    if m[5]?
      str = m[5]
    else
      str = ''
    @substituteValues.push [ofs, lenDiff, str]

  commitSubstitute: ->
    debug 'commitSubstitute insertValues=%o', @substituteValues
    @target.substitute @substituteValues
    return


stages =
  assignBegin:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      return
    '#': (value) ->
      @enterObjectKey ''
      @stage = stages.assignHasKey
      return
  assignHasKey:
    '|': ->
      @stage = stages.assignBegin
      return
    ':': ->
      @rawNext = false
      @stage = stages.assignHasColon
      return
    '[': ->
      @startModify stages.assignHasModify
      return
  assignHasColon:
    value: (value) ->
      @assignValue value
      @stage = stages.assignHasValue
      return
  assignHasValue:
    '|': ->
      @resetPath()
      @stage = stages.assignBegin
      return
    ']': ->
      if @scopeStack.length == 0
        throw new PrePatchError()
      # @resetPath()
      @stage = stages.modifyEnd
      return
    end: ->
      if @scopeStack.length > 0
        throw new PrePatchError()
  assignHasModify:
    '|': ->
      @resetPath()
      @stage = stages.assignBegin
      return
    ']': ->
      if @scopeStack.length == 0
        throw new PrePatchError()
      # @resetPath()
      @stage = stages.modifyEnd
      return
    end: ->
      if @scopeStack.length > 0
        throw new PrePatchError()

  replaceBegin:
    value: (value) ->
      @enterArrayKey value
      @stage = stages.replaceHasKey
      return
  replaceNextKey:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.replaceHasKey
      return
  replaceHasKey:
    '|': ->
      @stage = stages.replaceNextKey
      return
    ':': ->
      @rawNext = false
      @stage = stages.replaceHasColon
      @startReplace()
      return
    '[': ->
      @startModify stages.replaceHasModify
      return
  replaceHasColon:
    value: (value) ->
      @addReplace value
      @stage = stages.replaceHasValue
      return
  replaceHasValue:
    ':': ->
      @rawNext = false
      @stage = stages.replaceHasColon
      return
    '|': ->
      @commitReplace()
      @resetPath()
      @stage = stages.replaceBegin
      return
    ']': ->
      @commitReplace()
      @stage = stages.modifyEnd
      return
  replaceHasModify:
    '|': ->
      @commitReplace()
      @resetPath()
      @stage = stages.replaceBegin
      return
    ']': ->
      @commitReplace()
      @stage = stages.modifyEnd
      return

  unsetBegin:
    value: (value) ->
      @doUnset value
      @stage = stages.unsetHas
      return
    '#': ->
      @doUnset ''
      @stage = stages.unsetHas
      return
  unsetHas:
    ']': ->
      @stage = stages.modifyEnd
      return
    '|': ->
      @stage = stages.unsetBegin
      return

  deleteBegin:
    value: (value) ->
      @doDelete value
      @stage = stages.deleteHas
      return
    '#': ->
      @doDelete ''
      @stage = stages.deleteHas
      return
  deleteHas:
    ']': ->
      @stage = stages.modifyEnd
      return
    '|': ->
      @stage = stages.deleteBegin
      return

  insertBegin:
    value: (value) ->
      @startInsert value
      @stage = stages.insertHasKey
      return
  insertHasKey:
    ':': ->
      @stage = stages.insertHasColon
      @rawNext = false
      return
  insertHasColon:
    value: (value) ->
      @addInsert value
      @stage = stages.insertHasValue
      return
  insertHasValue:
    ':': ->
      @stage = stages.insertHasColon
      @rawNext = false
      return
    '|': ->
      @commitInsert()
      @stage = stages.insertBegin
      return
    ']': ->
      @commitInsert()
      @stage = stages.modifyEnd
      return

  moveBegin:
    value: (value) ->
      @doMove value
      @stage = stages.moveHas
      return
  moveHas:
    ']': ->
      @stage = stages.modifyEnd
      return
    '|': ->
      @stage = stages.moveBegin
      return

  substituteBegin:
    value: (value) ->
      @startSubstitute value
      @stage = stages.substituteHas
      return
  substituteHas:
    ']': ->
      @commitSubstitute()
      @stage = stages.modifyEnd
      return
    '|': ->
      @stage = stages.substituteNext
      return
  substituteNext:
    value: (value) ->
      @addSubstitute value
      @stage = stages.substituteHas
      return


  modifyEnd:
    canPop: true
    '[': ->
      @resetPath()
      @continueModify()

  patchBegin:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      return
    '#': (value) ->
      @enterObjectKey ''
      @stage = stages.assignHasKey
      return
    '[': ->
      @startModify stages.patchHasModify
      return

  patchHasModify:
    value: (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      return
    '#': (value) ->
      @enterObjectKey value
      @stage = stages.assignHasKey
      return
    end: ->
      if @scopeStack.length > 0
        throw new PrePatchError()

do ->
  for name, stage of stages
    stage.name = name


class Patcher

  constructor: (@wsonDiff, options) ->

  patchTarget: (target, delta) ->
    debug 'patch: target=%o, delta=%o', target, delta
    if not delta?
      return
    try
      if delta[0] != '|'
        value = @wsonDiff.WSON.parse delta
        target.assign null, value
        return

      state = new State @wsonDiff.WSON, delta, 1, target, stages.patchBegin

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
            state.popScope()
          state.rawNext = true
          state.skipNext = 0
          handler.call state, value, nextPos
          debug 'patch: pos=%o, rawNext=%o, skipNext=%o, stage.name=%o', state.pos, state.rawNext, state.skipNext, state.stage?.name
          state.pos = nextPos
          if state.skipNext > 0
            state.pos += state.skipNext
            return [state.rawNext, state.skipNext]
          else
            return state.rawNext
        backrefCb: (refIdx) -> target.get refIdx

      state.pos = delta.length
      loop
        debug 'patch: done: stage=%o', state.stage.name
        handler = state.stage.end
        if handler
          break
        state.popScope()
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









