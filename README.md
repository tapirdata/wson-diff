# wson-diff [![Build Status](https://secure.travis-ci.org/tapirdata/wson-diff.png?branch=master)](https://travis-ci.org/tapirdata/wson-diff) [![Dependency Status](https://david-dm.org/tapirdata/wson-diff.svg)](https://david-dm.org/tapirdata/wson-diff) [![devDependency Status](https://david-dm.org/tapirdata/wson-diff/dev-status.svg)](https://david-dm.org/tapirdata/wson-diff#info=devDependencies)
>  A differ/patcher for arbitrary values that presents diffs in a terse WSON-like format.

## Usage

```bash
$ npm install wson-diff
```

```js
wd = require('wson-diff')();

var have = {
  name: "otto",
  size: 177.3,
  completed: ["forth", "javascript", "c++", "haskell"],
  active: true,
  message: 'My hovercraft is full of eels.'
};

var wish = {
  name: "rudi",
  size: 177.4,
  completed: ["forth", "coffeescript", "haskell", "c++", "lisp"],
  active: false,
  message: 'My hovercraft is full of eels!'
};

var delta = wd.diff(have, wish);
console.log('delta="%s"', delta);
// delta="|active:#f|completed[m3@2][i4:lisp][r1:coffeescript]|message[s29=!]|name:rudi|size:#177.4"

var result = wd.patch(have, delta);
console.log('result="%j"', result);
// Now result (and have) is deep equal to wish.
```

to be continued...
