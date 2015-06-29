'use strict'

_ = require 'lodash'
wsonDiff = require '../src/'

chai = require 'chai'
expect = chai.expect

setup = require './fixtures/setups'
items = require './fixtures/patch-items'


try
  util = require 'util'
catch
  util = null

saveRepr = (x) ->
  if util
    util.inspect x, depth: null
  else
    try
      JSON.stringify x
    catch
      String x


for setup in require './fixtures/setups'
  describe setup.name, ->
    wDiff = wsonDiff setup.options
    describe 'patch', ->
      for item in items
        do (item) ->
          patcher = wDiff.createPatcher()
          have = _.cloneDeep item.have
          if item.failPos?
            it "should fail to patch #{saveRepr have} with '#{item.delta}' @#{item.failPos}.", ->
              try
                patcher.patch have, item.delta
              catch e_
                e = e_
              expect(e).to.be.instanceof wsonDiff.PatchError
              expect(e.pos).to.be.equal item.failPos
              if item.failCause
                expect(e.cause).to.match item.failCause
          else
            it "should patch #{saveRepr have} with '#{item.delta}' to #{saveRepr item.wish}.", ->
              expect(patcher.patch have, item.delta).to.be.deep.equal item.wish


