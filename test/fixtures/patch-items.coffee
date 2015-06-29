
module.exports = [
  # set
  {
    have:  null
    delta: 'foo'
    wish: 'foo'
  }
  {
    have:  null
    delta: '[foo]'
    wish: ['foo']
  }
  {
    have: {foo: 'FOO', bar: 'BAR'}
    delta: 'foo'
    wish: 'foo'
  }
  # basic
  {
    have: {foo: 'FOO', bar: 'BAR'}
    delta: '|foo:FU'
    wish: {foo: 'FU', bar: 'BAR'}
  }
  {
    have: {foo: 'FOO', bar: 'BAR'}
    delta: '|foo:[FU|BA]'
    wish: {foo: ['FU', 'BA'], bar: 'BAR'}
  }
  {
    have: {foo: 'FOO', bar: 'BAR'}
    delta: '|foo:FU|baz:BAZ'
    wish: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}
  }
  {
    have: {foo: 'FOO', bar: 'BAR'}
    delta: '|#:BAZ'
    wish: {foo: 'FOO', bar: 'BAR', '': 'BAZ'}
  }
  # basic fail
  {
    have: {}
    delta: ''
    failPos: 0
    failCause: /unexpected end/
  }
  {
    have: {}
    delta: '|foo:FU|'
    failPos: 8
    failCause: /unexpected end/
  }
  {
    have: {}
    delta: '|foo#:FU|'
    failPos: 4
    failCause: /unexpected '#'/
  }
  {
    have: {}
    delta: '|#foo:FU|'
    failPos: 2
    failCause: /unexpected 'f'/
  }
  {
    have: {}
    delta: '|foo|bar|baz:FU'
    failPos: 5
    failCause: /can't index scalar/
  }
  {
    have: {foo: {}}
    delta: '|foo|bar|baz:FU'
    failPos: 9
    failCause: /can't index scalar/
  }
  # multi path
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff|foo:FU|beff|baz:BAZ'
    wish: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  # scope
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ}'
    wish: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ}|zoo:ZOO'
    wish: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}, zoo: 'ZOO'}
  }
  # scope fail
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ'
    failPos: 20
    failCause: /unexpected end/
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ}}'
    failPos: 21
    failCause: /unexpected '}'/
  }
  # array set
  {
    have: ['a', 'b', 'c']
    delta: '|1:B'
    wish: ['a', 'B', 'c']
  }
  {
    have: ['a', ['b'], 'c']
    delta: '|1|0:B'
    wish: ['a', ['B'], 'c']
  }
  {
    have: ['a', x: 'b', 'c']
    delta: '|1|x:B'
    wish: ['a', x: 'B', 'c']
  }
  {
    have: foo: ['a', x: 'b', 'c']
    delta: '|foo|1|x:B'
    wish: foo: ['a', x: 'B', 'c']
  }
  # array set fail
  {
    have: ['a', 'b', 'c']
    delta: '|a:B'
    failPos: 1
    failCause: /non-numeric index/
  }
  # delete
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[-bar]'
    wish: {beff: {foo: 'FOO'}}
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[-bar|foo]'
    wish: {beff: {}}
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|[-beff]'
    wish: {}
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR', '': 'NIL'}}
    delta: '|beff[-#|foo]'
    wish: {beff: {bar: 'BAR'}}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-1]'
    wish: {beff: ['a', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-1|3]'
    wish: {beff: ['a', 'c', 'd', 'f', 'g']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-1~2|2~2]'
    wish: {beff: ['a', 'd', 'g']}
  }
  # delete fail
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-a]'
    failPos: 7
    failCause: /ill-formed range/
  }
  # insert
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1:X]'
    wish: {beff: ['a', 'X', 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+7:X]'
    wish: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'X']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1:X:[Y|Z]]'
    wish: {beff: ['a', 'X', ['Y', 'Z'], 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1:X:[Y|Z]|0:A]'
    wish: {beff: ['A', 'a', 'X', ['Y', 'Z'], 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  # insert fail
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1]'
    failPos: 8
    failCause: /unexpected ']'/
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+:1]'
    failPos: 7
    failCause: /unexpected ':'/
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+a:X]'
    failPos: 7
    failCause: /non-numeric index/
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[+1:X]'
    failPos: 6
    failCause: /unexpected '\+'/
  }
  # move
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1@4]'
    wish: {beff: ['a', 'c', 'd', 'e', 'b', 'f', 'g']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1~2@4]'
    wish: {beff: ['a', 'd', 'e', 'f', 'b', 'c', 'g']}
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1~2@4|1@0]'
    wish: {beff: ['d', 'a', 'e', 'f', 'b', 'c', 'g']}
  }
  # move fail
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1]'
    failPos: 7
    failCause: /ill-formed move/
  }
  {
    have: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1@]'
    failPos: 7
    failCause: /ill-formed move/
  }
  {
    have: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[!1@4]'
    failPos: 6
    failCause: /unexpected '!'/
  }
]
