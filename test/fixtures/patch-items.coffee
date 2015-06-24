
module.exports = [
  {
    old:  null
    str: 'foo'
    new: 'foo'
  }
  {
    old:  null
    str: '[foo]'
    new: ['foo']
  }
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: 'foo'
    new: 'foo'
  }
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: '|foo:FU'
    new: {foo: 'FU', bar: 'BAR'}
  }
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: '|foo:FU|baz:BAZ'
    new: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff|foo:FU|beff|baz:BAZ'
    new: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  {
    old: {}
    str: ''
    failPos: 0
  }
  {
    old: {}
    str: '|foo:FU|'
    failPos: 8
  }
  {
    old: {}
    str: '|foo|bar|baz:FU'
    failPos: 8
  }
]
