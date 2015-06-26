
module.exports = [
  # set
  {
    source:  null
    delta: 'foo'
    dest: 'foo'
  }
  {
    source:  null
    delta: '[foo]'
    dest: ['foo']
  }
  {
    source: {foo: 'FOO', bar: 'BAR'}
    delta: 'foo'
    dest: 'foo'
  }
  # basic
  {
    source: {foo: 'FOO', bar: 'BAR'}
    delta: '|foo:FU'
    dest: {foo: 'FU', bar: 'BAR'}
  }
  {
    source: {foo: 'FOO', bar: 'BAR'}
    delta: '|foo:[FU|BA]'
    dest: {foo: ['FU', 'BA'], bar: 'BAR'}
  }
  {
    source: {foo: 'FOO', bar: 'BAR'}
    delta: '|foo:FU|baz:BAZ'
    dest: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}
  }
  {
    source: {foo: 'FOO', bar: 'BAR'}
    delta: '|#:BAZ'
    dest: {foo: 'FOO', bar: 'BAR', '': 'BAZ'}
  }
  # basic fail
  {
    source: {}
    delta: ''
    failPos: 0
    failCause: /unexpected end/
  }
  {
    source: {}
    delta: '|foo:FU|'
    failPos: 8
    failCause: /unexpected end/
  }
  {
    source: {}
    delta: '|foo#:FU|'
    failPos: 4
    failCause: /unexpected '#'/
  }
  {
    source: {}
    delta: '|#foo:FU|'
    failPos: 2
    failCause: /unexpected 'f'/
  }
  {
    source: {}
    delta: '|foo|bar|baz:FU'
    failPos: 5
    failCause: /can't index scalar/
  }
  {
    source: {foo: {}}
    delta: '|foo|bar|baz:FU'
    failPos: 9
    failCause: /can't index scalar/
  }
  # multi path
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff|foo:FU|beff|baz:BAZ'
    dest: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  # scope
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ}'
    dest: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}}
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ}|zoo:ZOO'
    dest: {beff: {foo: 'FU', bar: 'BAR', baz: 'BAZ'}, zoo: 'ZOO'}
  }
  # scope fail
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ'
    failPos: 20
    failCause: /unexpected end/
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff{foo:FU|baz:BAZ}}'
    failPos: 21
    failCause: /unexpected '}'/
  }
  # array set
  {
    source: ['a', 'b', 'c']
    delta: '|1:B'
    dest: ['a', 'B', 'c']
  }
  {
    source: ['a', ['b'], 'c']
    delta: '|1|0:B'
    dest: ['a', ['B'], 'c']
  }
  {
    source: ['a', x: 'b', 'c']
    delta: '|1|x:B'
    dest: ['a', x: 'B', 'c']
  }
  {
    source: foo: ['a', x: 'b', 'c']
    delta: '|foo|1|x:B'
    dest: foo: ['a', x: 'B', 'c']
  }
  # array set fail
  {
    source: ['a', 'b', 'c']
    delta: '|a:B'
    failPos: 1
    failCause: /non-numeric index/
  }
  # delete
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[-bar]'
    dest: {beff: {foo: 'FOO'}}
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[-bar|foo]'
    dest: {beff: {}}
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|[-beff]'
    dest: {}
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR', '': 'NIL'}}
    delta: '|beff[-#|foo]'
    dest: {beff: {bar: 'BAR'}}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-1]'
    dest: {beff: ['a', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-1|3]'
    dest: {beff: ['a', 'c', 'd', 'f', 'g']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-1~2|2~2]'
    dest: {beff: ['a', 'd', 'g']}
  }
  # delete fail
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[-a]'
    failPos: 7
    failCause: /ill-formed range/
  }
  # insert
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1:X]'
    dest: {beff: ['a', 'X', 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+7:X]'
    dest: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'X']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1:X:[Y|Z]]'
    dest: {beff: ['a', 'X', ['Y', 'Z'], 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1:X:[Y|Z]|0:A]'
    dest: {beff: ['A', 'a', 'X', ['Y', 'Z'], 'b', 'c', 'd', 'e', 'f', 'g']}
  }
  # insert fail
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+1]'
    failPos: 8
    failCause: /unexpected ']'/
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+:1]'
    failPos: 7
    failCause: /unexpected ':'/
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[+a:X]'
    failPos: 7
    failCause: /non-numeric index/
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[+1:X]'
    failPos: 6
    failCause: /unexpected '\+'/
  }
  # move
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1@4]'
    dest: {beff: ['a', 'c', 'd', 'e', 'b', 'f', 'g']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1~2@4]'
    dest: {beff: ['a', 'd', 'e', 'f', 'b', 'c', 'g']}
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1~2@4|1@0]'
    dest: {beff: ['d', 'a', 'e', 'f', 'b', 'c', 'g']}
  }
  # move fail
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1]'
    failPos: 7
    failCause: /ill-formed move/
  }
  {
    source: {beff: ['a', 'b', 'c', 'd', 'e', 'f', 'g']}
    delta: '|beff[!1@]'
    failPos: 7
    failCause: /ill-formed move/
  }
  {
    source: {beff: {foo: 'FOO', bar: 'BAR'}}
    delta: '|beff[!1@4]'
    failPos: 6
    failCause: /unexpected '!'/
  }
]
