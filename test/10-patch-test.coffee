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
    diff = wsonDiff setup.options
    patcher = diff.createPatcher()
    describe 'patch', ->
      for item in items
        do (item) ->
          target = _.cloneDeep item.old
          if item.failPos?
            it "should fail to patch #{saveRepr target} with '#{item.str}' @#{item.failPos}.", ->
              try
                patcher.patch target, item.str
              catch e_
                e = e_
              expect(e).to.be.instanceof wsonDiff.PatchError
              expect(e.pos).to.be.equal item.failPos
          else
            it "should patch #{saveRepr target} with '#{item.str}' to #{saveRepr item.new}.", ->
              expect(patcher.patch target, item.str).to.be.deep.equal item.new


