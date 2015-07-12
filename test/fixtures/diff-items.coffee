extdefs = require './extdefs'

module.exports = [
  {
    description: 'same number'
    have: 42
    wish: 42
    delta: null
  }
  {
    description: 'changes number'
    have: 43
    wish: 42
    delta: '#42'
  }
  {
    description: 'object to number'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: 42
    delta: '#42'
  }
  {
    description: 'number to object'
    have: 42
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    description: 'array to object'
    have: []
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: '{bar:{a:alice|b:bob}|foo:{a:alice|b:bob}}'
  }
  {
    description: 'object to array'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: []
    delta: '[]'
  }
  {
    description: 'same object'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    delta: null
  }
  {
    description: 'object change single'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo|b:bobby'
  }
  {
    description: 'object change multi'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, bar: {a: 'alice', b: 'bobby'}}
    delta: '|bar|b:bobby|foo|b:bobby'
  }
  {
    description: 'object change collected multi'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf', b: 'bobby'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[=a:alf|b:bobby]'
  }
  {
    description: 'object changed whole sub'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bob'}, bar: 'BAR'}
    delta: '|bar:BAR'
  }
  # with del
  {
    description: 'object del and replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar]foo|b:bobby'
  }
  {
    description: 'object multi del and replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}}
    delta: '|[-bar|baz]foo|b:bobby'
  }
  {
    description: 'object del and multi replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}, baz: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alice', b: 'bobby'}, baz: {a: 'alf', b: 'bob'}}
    delta: '|[-bar]baz|a:alf|foo|b:bobby'
  }
  {
    description: 'object del and multi collected replace'
    have: {foo: {a: 'alice', b: 'bob'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b][=a:alf|c:chris]'
  }
  {
    description: 'object multi del and single replace '
    have: {foo: {a: 'alice', b: 'bob', c: 'chris'}, bar: {a: 'alice', b: 'bob'}}
    wish: {foo: {a: 'alf'}, bar: {a: 'alice', b: 'bob'}}
    delta: '|foo[-b|c][=a:alf]'
  }
  {
    description: 'object deep multi diff'
    have: {foo: {members: {a: 'alice', b: 'bob'}, contrahents: {e: 'eve', m: 'mallet'}}, bar: {members: {a: 'alice', b: 'bob'}}}
    wish: {foo: {members: {a: 'Alice', b: 'Bob'}, contrahents: {e: 'Eve', m: 'Mallet'}}, bar: {members: {a: 'Alice', b: 'Bob'}}}
  }
  {
    description: 'no change'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdefghijkl'.split ''
    delta: null
  }
  {
    description: 'multi deletes'
    have: 'abcdefghijkl'.split ''
    wish: 'abdefghkl'.split ''
    delta: '|[d8+1|2]'
  }
  {
    description: 'single forward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abdefcghijkl'.split ''
    delta: '|[m2@5]'
  }
  {
    description: 'single backward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abcidefghjkl'.split ''
    delta: '|[m8@3]'
  }
  {
    description: 'double block forward move '
    have: 'abcdefghijkl'.split ''
    wish: 'abefgcdhijkl'.split ''
    delta: '|[m2+1@5]'
  }
  {
    description: 'double isolated forward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abdfghcijekl'.split ''
    delta: '|[m2@7|3@9]'
  }
  {
    description: 'double block backward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abcijdefghkl'.split ''
    delta: '|[m8+1@3]'
  }
  {
    description: 'double isolated backward move'
    have: 'abcdefghijkl'.split ''
    wish: 'abcidkefghjl'.split ''
    delta: '|[m8@3|10@5]'
  }
  {
    description: 'double block forward exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abefgdchijkl'.split ''
    delta: '|[m2-1@5]'
  }
  {
    description: 'double block backward exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abjicdefghkl'.split ''
    delta: '|[m8-1@2]'
  }
  {
    description: 'exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abciefghdjkl'.split ''
    delta: '|[m8@3|4@8]'
  }
  {
    description: 'block exchange move'
    have: 'abcdefghijkl'.split ''
    wish: 'abijkfghcdel'.split ''
    delta: '|[m8+2@2|8+2@5]'
  }
  {
    description: 'multi exchange move #1'
    have: 'abcdefghijkl'.split ''
    wish: 'abefjgckldhi'.split ''
    delta: '|[m2@6|2@6|9@4|10+1@7]'
  }
  {
    description: 'multi exchange move #2'
    have: 'abcdefghijkl'.split ''
    wish: 'jgdhiabecklf'.split ''
    delta: '|[m9@0|7@1|5@2|8+1@3|8@7|9@11]'
  }
  {
    description: 'reverse move'
    have: 'abcdefghijkl'.split ''
    wish: 'lkjihgfedcba'.split ''
    delta: '|[m1-10@0]'
  }
  {
    description: 'move with duplicates'
    have: 'abcabcde'.split ''
    wish: 'ababdcec'.split ''
    delta: '|[m2@7|5@4]'
  }
  {
    description: 'backward split delete'
    have: 'abcdefghijkl'.split ''
    wish: 'abicdefkl'.split ''
    delta: '|[d9|6+1][m6@2]'
  }
  {
    description: 'forward split delete'
    have: 'abcdefghijkl'.split ''
    wish: 'abghijkle'.split ''
    delta: '|[d5|2+1][m2@8]'
  }
  {
    description: 'multi delete & move'
    have: 'abcdefghijkl'.split ''
    wish: 'ajlefbc'.split ''
    delta: '|[d10|6+2|3][m5@1|6@2|5+1@3]'
  }
  {
    description: 'single insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdXefghijkl'.split ''
    delta: '|[i4:X]'
  }
  {
    description: 'append'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdefghijklm'.split ''
    delta: '|[i12:m]'
  }
  {
    description: 'insert that needs quoting'
    have: 'a,b,c,d,e,f,g,h,i,j,k,l'.split ','
    wish: 'a,b,c,d,e,f,g,[],h,i,j,k,l'.split ','
    delta: '|[i7:`a`e]'
  }
  {
    description: 'insert array'
    have: [['a'], ['c']]
    wish: [['a'], ['b'], ['c']]
    delta: '|[i1:[b]]'
  }
  {
    description: 'double block insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdXYefghijkl'.split ''
    delta: '|[i4:X:Y]'
  }
  {
    description: 'double isolated insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdXefYghijkl'.split ''
    delta: '|[i6:Y|4:X]'
  }
  {
    description: 'multiple insert'
    have: 'abcdefghijkl'.split ''
    wish: 'abcXYdefghiZUVjkl'.split ''
  }
  {
    description: 'move & insert'
    have: 'abcdefghijkl'.split ''
    wish: 'aXYldfghbciZUVjek'.split ''
  }
  {
    description: 'single replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdeFghijkl'.split ''
  }
  {
    description: 'double block replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abcdeFGhijkl'.split ''
  }
  {
    description: 'move & replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abgcdeFHijkl'.split ''
  }
  {
    description: 'delete, move & replace'
    have: 'abcdefghijkl'.split ''
    wish: 'abjKdefhIl'.split ''
  }
  {
    description: 'move, insert & replace'
    have: 'abcdefghijkl'.split ''
    wish: 'jkaeFgbcDhilM'.split ''
  }
  {
    description: 'replace missing duplicates'
    have: 'abcabcde'.split ''
    wish: 'ababdccec'.split ''
  }
  {
    description: 'delete superfluous duplicates'
    have: 'abcabcde'.split ''
    wish: 'ababdce'.split ''
  }
  {
    description: 'total replace'
    have: 'abcdefghijkl'.split ''
    wish: 'ABCDEFGHIJKL'.split ''
  }
  {
    description: 'deep array modify'
    have: [['a','b','c'],['e','f','g']]
    wish: [['a','B','c'],['E','f','G']]
    delta: '|[r0[r1:B]|1[r0:E|2:G]]'
  }
  {
    description: 'array of objects no change'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {b: 4}, {c: 5}]
  }
  {
    description: 'array of objects move'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {c: 5}, {b: 4}]
  }
  {
    description: 'array of objects insert'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {b: 4}, {x: 11}, {c: 5}]
  }
  {
    description: 'array of objects replace'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 3}, {b: 14}, {c: 5}]
  }
  {
    description: 'array of objects multi replace'
    have: [{a: 3}, {b: 4}, {c: 5}]
    wish: [{a: 13}, {b: 14}, {c: 15}]
  }
  {
    description: 'add circular reference'
    have: do -> x = foo: a: {y: 3}; x
    wish: do -> x = foo: a: {y: 3}; x.foo.a.x = x; x
    delta: '|foo|a|x:|2'
  }
  {
    description: 'add circular reference'
    have: do -> x = foo: a: {y: 3}; x
    wish: do -> x = foo: a: {y: 3}; x.foo.a.foo = x.foo; x
    delta: '|foo|a|foo:|1'
  }
  {
    description: 'double replace, no limit'
    have: 'abcdefghijkl'.split ''
    wish: 'abcDEfghijkl'.split ''
    delta: '|[r3:D:E]'
  }
  {
    description: 'double replace, limit=2'
    diffOptions: arrayLimit: -> 2
    have: 'abcdefghijkl'.split ''
    wish: 'abcDEfghijkl'.split ''
    delta: '[a|b|c|D|E|f|g|h|i|j|k|l]'
  }
  {
    description: 'single replace, limit=2'
    diffOptions: arrayLimit: -> 2
    have: 'abcdefghijkl'.split ''
    wish: 'abcDefghijkl'.split ''
    delta: '|[r3:D]'
  }
  {
    description: 'replace object by custum object'
    have: {a: {x: 3, y: 4}}
    wish: {a: new extdefs.Point(3, 4)}
    delta: '|a:[:Point|#3|#4]'
    wsonClone: true
  }
  {
    description: 'replace patch custum object'
    have: {a: new extdefs.Point(3, 4)}
    wish: {a: new extdefs.Point(3, 14)}
    delta: '|a|y:#14'
    wsonClone: true
  }
  {
    description: 'replace patch custum object with diffKeys'
    have: {a: new extdefs.Foo(3, 4, 5)}
    wish: {a: new extdefs.Foo(3, 14, 5)}
    delta: '|a|y:#14'
    wsonClone: true
  }
  {
    description: 'replace patch custum object with diffKeys; ignore changed attribute'
    have: {a: new extdefs.Foo(3, 4, 5)}
    wish: {a: new extdefs.Foo(3, 14, 15)}
    delta: '|a|y:#14'
    noPatch: true
    wsonClone: true
  }
  {
    description: 'deep multi array replace'
    have:
      foo:
        members:
          a: 'alice'.split('')
          b: 'bob'.split('')
        contrahents: 
          e: 'eve'.split('')
          m: 'mallet'.split('')
      bar: 
        members:
          a: 'alice'.split('')
          b: 'bob'.split('')
    wish:
      foo:
        members:
          a: 'Alice'.split('')
          b: 'Bob'.split('')
        contrahents: 
          e: 'Eve'.split('')
          m: 'Mallet'.split('')
      bar: 
        members:
          a: 'Alice'.split('')
          b: 'Bob'.split('')
    delta: '|bar|members[=a[r0:A]|b[r0:B]]|foo[=contrahents[=e[r0:E]|m[r0:M]]|members[=a[r0:A]|b[r0:B]]]'
  }       
  {
    description: 'deep multi string replace'
    have:
      foo:
        members:
          a: 'alice'
          b: 'bob'
        contrahents: 
          e: 'eve'
          m: 'mallet'
      bar: 
        members:
          a: 'alice'
          b: 'bob'
    wish:
      foo:
        members:
          a: 'Alice'
          b: 'Bob'
        contrahents: 
          e: 'Eve'
          m: 'Mallet'
      bar: 
        members:
          a: 'Alice'
          b: 'Bob'
    delta: '|bar|members[=a:Alice|b:Bob]|foo[=contrahents[=e:Eve|m:Mallet]|members[=a:Alice|b:Bob]]'
  }       
  {
    description: 'deep multi string replace without edge'
    diffOptions:
      stringEdge: 0
    have:
      foo:
        members:
          a: 'alice'
          b: 'bob'
        contrahents: 
          e: 'eve'
          m: 'mallet'
      bar: 
        members:
          a: 'alice'
          b: 'bob'
    wish:
      foo:
        members:
          a: 'Alice'
          b: 'Bob'
        contrahents: 
          e: 'Eve'
          m: 'Mallet'
      bar: 
        members:
          a: 'Alice'
          b: 'Bob'
    delta: '|bar|members[=a[s0+0=A]|b[s0+0=B]]|foo[=contrahents[=e[s0+0=E]|m[s0+0=M]]|members[=a[s0+0=A]|b[s0+0=B]]]'      
  }       
]

