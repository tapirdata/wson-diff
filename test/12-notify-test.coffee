'use strict'

_ = require 'lodash'
debug = require('debug') 'wson-diff:test'

wsonDiff = require '../src/'

chai = require 'chai'
expect = chai.expect

setup = require './fixtures/setups'
items = require './fixtures/notify-items'


try
  util = require 'util'
catch
  util = null

saveRepr = (x) ->
  if util?
    util.inspect x, depth: null
  else
    try
      JSON.stringify x
    catch
      String x


class Notifier

  constructor: (@budgeTest) ->
    @nfys = []
    @keyStack = []

  checkedBudge: (up, key) ->
    # console.log 'checkedBudge', up, key
    keyStack = @keyStack
    if up > 0
      keyStack.splice keyStack.length - up
    if key?
      keyStack.push key
    @budgeTest.apply @, _(keyStack).reverse().value()

  fullPath: (key) ->
    path = @keyStack
    if key?
      path.concat [key]
    else
      _.clone path

  unset: (key) ->
    @nfys.push ['unset', @fullPath(key)]
  assign: (key, value) ->
    @nfys.push ['assign', @fullPath(key), value]

  delete: (idx, len) ->
    @nfys.push ['delete', @fullPath(), idx, len]
  move: (srcIdx, dstIdx, len, reverse) ->
    @nfys.push ['move', @fullPath(), srcIdx, dstIdx, reverse]
  insert: (idx, values) ->
    @nfys.push ['insert', @fullPath(), idx, values]
  replace: (idx, values) ->
    @nfys.push ['replace', @fullPath(), idx, values]

  substitute: (patches) ->
    @nfys.push ['substitute', @fullPath(), patches]


for setup in require './fixtures/setups'
  describe setup.name, ->
    wdiff = wsonDiff setup.options
    describe 'notify', ->
      for item in items
        do (item) ->
          debug 'patch: have=%o, delta=%o', item.have, item.delta
          patcher = wdiff.createPatcher item.patchOptions
          notifier = new Notifier item.budgeTest
          describe item.description, ->
            it "should patch #{saveRepr item.have} with '#{item.delta}' notify #{saveRepr item.nfys}.", ->
              patcher.patch item.have, item.delta, notifier
              expect(notifier.nfys).to.be.deep.equal item.nfys

