
module.exports = [
  # set
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
  # basic
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: '|foo:FU'
    new: {foo: 'FU', bar: 'BAR'}
  }
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: '|foo:[FU|BA]'
    new: {foo: ['FU', 'BA'], bar: 'BAR'}
  }
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: '|foo:FU|baz:BAZ'
    new: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}
  }
  {
    old: {foo: 'FOO', bar: 'BAR'}
    str: '|#:BAZ'
    new: {foo: 'FOO', bar: 'BAR', '': 'BAZ'}
  }
  # basic fail
  {
    old: {}
    str: ''
    failPos: 0
    failCause: /unexpected end/
  }
  {
    old: {}
    str: '|foo:FU|'
    failPos: 8
    failCause: /unexpected end/
  }
  {
    old: {}
    str: '|foo#:FU|'
    failPos: 4
    failCause: /unexpected '#'/
  }
  {
    old: {}
    str: '|#foo:FU|'
    failPos: 2
    failCause: /unexpected 'f'/
  }
  {
    old: {}
    str: '|foo|bar|baz:FU'
    failPos: 5
    failCause: /can't index scalar/
  }
  {
    old: {foo: {}}
    str: '|foo|bar|baz:FU'
    failPos: 9
    failCause: /can't index scalar/
  }
  # multi path
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff|foo:FU|beff|baz:BAZ'
    new: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  # scope
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff{foo:FU|baz:BAZ}'
    new: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff{foo:FU|baz:BAZ}|zoo:ZOO'
    new: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}, zoo: 'ZOO'}
  }
  # scope fail
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff{foo:FU|baz:BAZ'
    failPos: 20
    failCause: /unexpected end/
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff{foo:FU|baz:BAZ}}'
    failPos: 21
    failCause: /unexpected '}'/
  }
  # array set
  {
    old: ['a', 'b', 'c']
    str: '|1:B'
    new: ['a', 'B', 'c']
  }
  {
    old: ['a', ['b'], 'c']
    str: '|1|0:B'
    new: ['a', ['B'], 'c']
  }
  {
    old: ['a', x: 'b', 'c']
    str: '|1|x:B'
    new: ['a', x: 'B', 'c']
  }
  {
    old: foo: ['a', x: 'b', 'c']
    str: '|foo|1|x:B'
    new: foo: ['a', x: 'B', 'c']
  }
  # array set fail
  {
    old: ['a', 'b', 'c']
    str: '|a:B'
    failPos: 1
    failCause: /non-numeric index/
  }
  # delete
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff[-bar]'
    new: {beff: {foo: 'FOO'}}
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff[-bar|foo]'
    new: {beff: {}}
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|[-beff]'
    new: {}
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR', '': 'NIL'}}
    str: '|beff[-#|foo]'
    new: {beff: {bar: 'BAR'}}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[-1]'
    new: {beff: ['a', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[-1|3]'
    new: {beff: ['a', 'c', 'd', 'f', 'g']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[-1~2|2~2]'
    new: {beff: ['a', 'd', 'g']}
  }
  # delete fail
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[-a]'
    failPos: 7
    failCause: /ill-formed range/
  }
  # insert
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+1:X]'
    new: {beff: ['a', 'X', 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+7:X]'
    new: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'X']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+1:X:[Y|Z]]'
    new: {beff: ['a', 'X', ['Y', 'Z'], 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+1:X:[Y|Z]|0:A]'
    new: {beff: ['A', 'a', 'X', ['Y', 'Z'], 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  # insert fail
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+1]'
    failPos: 8
    failCause: /unexpected ']'/
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+:1]'
    failPos: 7
    failCause: /unexpected ':'/
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[+a:X]'
    failPos: 7
    failCause: /non-numeric index/
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff[+1:X]'
    failPos: 6
    failCause: /unexpected '\+'/
  }
  # move
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[!1@4]'
    new: {beff: ['a', 'c', 'd', 'e', 'b', 'f', 'g']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[!1~2@4]'
    new: {beff: ['a', 'd', 'e', 'f', 'b', 'c', 'g']}
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[!1~2@4|1@0]'
    new: {beff: ['d', 'a', 'e', 'f', 'b', 'c', 'g']}
  }
  # move fail
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[!1]'
    failPos: 7
    failCause: /ill-formed move/
  }
  {
    old: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    str: '|beff[!1@]'
    failPos: 7
    failCause: /ill-formed move/
  }
  {
    old: {beff: {foo: 'FOO', bar: 'BAR'}}
    str: '|beff[!1@4]'
    failPos: 6
    failCause: /unexpected '!'/
  }
]
