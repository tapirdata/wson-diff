# wson-diff [![Build Status](https://secure.travis-ci.org/tapirdata/wson-diff.png?branch=master)](https://travis-ci.org/tapirdata/wson-diff) [![Dependency Status](https://david-dm.org/tapirdata/wson-diff.svg)](https://david-dm.org/tapirdata/wson-diff) [![devDependency Status](https://david-dm.org/tapirdata/wson-diff/dev-status.svg)](https://david-dm.org/tapirdata/wson-diff#info=devDependencies)
>  A differ/patcher for arbitrary values that presents delta in a terse WSON-like format.

## Usage

```bash
$ npm install wson-diff
```

```js
WDIF = require('wson-diff')();

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

var delta = WDIF.diff(have, wish);
console.log('delta="%s"', delta);
// delta="|active:#f|completed[m3@2][i4:lisp][r1:coffeescript]|message[s29=!]|name:rudi|size:#177.4"

var result = WDIF.patch(have, delta);
console.log('result="%j"', result);
// Now result (and have) is deep equal to wish.
```

## How deltas are build up

### Null delta

If `have` is deep equal to `wish`, `diff` returns `null`.  

Examples:

| `have`              | `wish`              |
|---------------------|---------------------|
| `23`                | `23`                |
| `{a: 3, b: 4}`      | `{a: 3, b: 4}`      | 
| `[3, 4]`            | `[3, 4]`            |
| `'hovercraft'`      | `'hovercraft'`      |

<a name="plain-delta"></a>
### Plain delta

```ebnf
plain delta ::= wson
```

Any WSON-string is a **plain delta**. Its semantics is: Ignore `have`, just use the WSON-stringified delta as the result.

A Plain delta will be produced for **scalars** (every **string**, **array**, or **object** except `Date`, which _are_ **scalars**) and if `have` and `wish` have different types.

Examples:

| `have`              | `wish`              |  `delta`         |
|---------------------|---------------------|------------------|
| `23`                | `42`                | #42              |
| `false`             | `true`              | #t               |
| `undefined`         | `null`              | #n               |
| `[3, 4]`            | `{a: 3, b: 4}`      | {a:3\|b:4}       |
| `{a: 3, b: 4}`      | `[3, 4]`            | [3\|4]           |

### Real delta

A **real delta** starts with a '|' followed by zero ore more [modifier deltas](#modifier-delta) followed by zero ore more [assign deltas](#assign-delta). The **assign deltas** are separated from each other and the **modifier deltas** by '|'.

<a name="path"></a>
### Path

A **path** consists of one ore more keys separated by '|'. Each key is a WSON-stringified **string**.

Examples:

| path                     | keys
|--------------------------|-------------
| a                        | 'a' 
| foo\|a\|members          | 'foo', 'a', 'members'
| foo\|\`a\`e\|#\|42       | 'foo', '[]', '', '42' (Special characters '[' and ']' are WSON-escaped; '#' is the empty string.)


### Assign delta

An **assign delta** consists of a [path](#path) followed by a ':', followed by a WSON-string **value**. Its semantics is: Use **path** to dive into the **object** (All keys but the last must reolve to **objects**). Use the last key to set or replace that property by **value**. 

| `have`                 | `wish`                        |  `delta`         |
|------------------------|-------------------------------|------------------|
| `{a: 3, b: 4}`         | `{a: 3, b: 42}`               | \|b:#42          |
| `{foo: {a: 3, b: 4}}`  | `{foo: {a: 3, b: 42}}`        | \|foo\|b:#42     |
| `{foo: {a: 3, b: 4}}`  | `{foo: {a: 3, b: 4, c: 5}}`   | \|foo\|c:#5      |


<a name="modifier-delta"></a>
### Modifier delta

A Modifier delta consists of a '[', followed by a **kind character**, followed by one or more '|'-separated kind-specific **item**, cloesd by a ']'.

<a name="path-delta"></a>
### Path delta

A Path delta is an [assign delta](#assign-delta) or a [path](#path) followed by one ore more [modifier deltas](#modifier-delta).


#### Object Modifier delta

There are two **modifier deltas** that operate on an **object**: **unset**, and **assign**:

##### Unset

- **kind character**: '-'
- **item**: **key**, a WSON-stringified **string**
- Semantics: Remove **key** from **object** 

Examples:

| `have`                | `wish`              |  `delta`         |
|-----------------------|---------------------|------------------|
| `{a: 3, b: 4, c: 5}`  | `{b: 4}`            | [-a\|c]          |

##### Assign

- **kind character**: '='
- **item**: a [path delta](#path-delta)
- Semantics: Set, replace or modify the referred value.

Examples:

| `have`                       | `wish`                      |  `delta`           |
|------------------------------|-----------------------------|--------------------|
| `{foo: {a: 3, b: 4, c: 5}}`  | `{foo: {a: 4, b: 3, c: 5}}` | \|foo[=a:#4\|b:#3] |

#### Array Modifier delta

There are four **modifier deltas** that operate on an **array**: **delete**, **insert**, **move** and **replace**.
Since **arrays** are assumed to be modifiable, these modifiers work _cumulative_: 

##### Delete

- **kind character**: 'd'
- **item**: an index optionally followed by '+' and length-extra-number 
- Semantics: Remove one ore more entries from the array.

Examples:

| `have`                  | `wish`                  |  `delta`         | Explenation
|-------------------------|-------------------------|------------------|------------------|
| `[2, 3, 5, 7, 11, 13]`  | `[2, 5, 7, 11, 13]`     | [d1]             | Delete one entry at index 1 |
| `[2, 3, 5, 7, 11, 13]`  | `[3, 5, 13]`            | [d0\|2+1]        | Delete one entry at index 0. From the resulting array delete 2 entries (one + 1) at index 2 |

##### Insert

- **kind character**: 'i'
- **item**: an index followed by one or more WSON-strings, each prefixed by a ':'
- Semantics: Insert ore more entries from the array.






to be continued...
