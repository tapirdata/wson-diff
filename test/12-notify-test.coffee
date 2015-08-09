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
    @nfys.push ['move', @fullPath(), srcIdx, dstIdx, len, reverse]
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
          notifier0 = new Notifier item.budgeTest0
          if item.budgeTest1?
            notifier1 = new Notifier item.budgeTest1
            notifiers = [notifier0, notifier1]
          else  
            notifiers = notifier0
          describe item.description, ->
            describe "patch #{saveRepr item.have} with '#{item.delta}'", ->
              patcher.patch item.have, item.delta, notifiers
              it "should notify #{saveRepr item.nfys0}.", ->
                expect(notifier0.nfys).to.be.deep.equal item.nfys0
              if item.budgeTest1?  
                it "should also notify #{saveRepr item.nfys1}.", ->
                  expect(notifier1.nfys).to.be.deep.equal item.nfys1

