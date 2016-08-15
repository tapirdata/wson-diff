let debug = require('debug')('wson-diff:patch');
import wson from 'wson';

import { WsonDiffError } from './errors';
import ValueTarget from './value-target';
import NotifierTarget from './notifier-target';

class PrePatchError extends WsonDiffError {
  constructor(cause) {
    super()
    this.name = 'PrePatchError';
    this.cause = cause;
  }
}


class PatchError extends WsonDiffError {
  constructor(s, pos, cause) {
    super()
    this.name = 'PatchError';
    this.s = s;
    this.pos = pos;
    this.cause = cause;
    if (this.pos == null) {
      this.pos = this.s.length;
    }
    if (!this.cause) {
      if (this.pos >= this.s.length) {
        var char = "end";
      } else {
        var char = `'${this.s[this.pos]}'`;
      }
      this.cause = `unexpected ${char}`;
    }
    this.message = `${this.cause} at '${this.s.slice(0, this.pos)}^${this.s.slice(this.pos)}'`;
  }
}


let reIndex = /^\d+$/;
let reRange = /^(\d+)(\+(\d+))?$/;
let reMove = /^(\d+)([+|-](\d+))?@(\d+)$/;
let reSubst = /^(\d+)([+|-](\d+))?(=(.+))?$/;

let TI_UNKNOW = 0;
let TI_STRING = 20;
let TI_ARRAY  = 24;
let TI_OBJECT = 32;


class State {

  constructor(WSON, delta, pos, target, stage) {
    this.WSON = WSON;
    this.delta = delta;
    this.pos = pos;
    this.target = target;
    this.stage = stage;
    this.scopeTi = null;
    this.currentTi = null;
    this.pendingKey = null;
    this.pendingUp = 0;
    this.targetDepth = 0;
    this.scopeDepth = 0;
    this.scopeStack  = [];
  }

  getCurrentTi() {
    let ti = this.currentTi;
    if (ti == null) {
      let { target } = this;
      if (target.get != null) {
        let value = target.get(0);
        ti = this.WSON.getTypeid(value);
        this.currentTi = ti;
        if (this.haveUp === 0) {
          this.scopeTi = ti;
        }
      } else {
        ti = TI_UNKNOW;
      }
    }
    return ti;
  }

  budgePending(withKey) {
    debug('budgePending withKey=%o pendingUp=%o pendingKey=%o', withKey, this.pendingUp, this.pendingKey);
    if (withKey && (this.pendingKey != null)) {
      this.target.budge(this.pendingUp, this.pendingKey);
      this.targetDepth -= this.pendingUp - 1;
      this.pendingUp = 0;
      this.currentTi = null;
      this.pendingKey = null;
    } else if (this.pendingUp > 0) {
      this.target.budge(this.pendingUp, null);
      this.targetDepth -= this.pendingUp;
      this.pendingUp = 0;
    }
  }

  resetPath() {
    debug('resetPath targetDepth=%o scopeDepth=%o', this.targetDepth, this.scopeDepth);
    this.pendingUp = this.targetDepth - this.scopeDepth;
    this.pendingKey = null;
    this.currentTi = this.scopeTi;
  }

  enterObjectKey(key) {
    this.budgePending(true);
    debug('enterObjectKey key=%o', key);
    let ti = this.getCurrentTi();
    if (ti !== TI_UNKNOW && ti !== TI_OBJECT) {
      if (ti === TI_ARRAY) {
        throw new PrePatchError(`can't index array ${this.target.get()} with object index ${key}`);
      } else {
        throw new PrePatchError(`can't index scalar ${this.target.get()}`);
      }
    }
    this.pendingKey = key;
  }

  enterArrayKey(skey) {
    this.budgePending(true);
    debug('enterArrayKey skey=%o', skey);
    let ti = this.getCurrentTi();
    if (!reIndex.test(skey)) {
      throw new PrePatchError(`non-numeric array index ${skey} for ${this.target.get()}`);
    }
    let key = Number(skey);
    if (ti !== TI_UNKNOW && ti !== TI_ARRAY) {
      if (ti === TI_OBJECT) {
        throw new PrePatchError(`can't index object ${this.target.get()} with array index ${key}`);
      } else {
        throw new PrePatchError(`can't index scalar ${this.target.get()}`);
      }
    }
    this.pendingKey = key;
  }

  pushScope(nextStage) {
    debug('pushScope scopeDepth=%o @targetDepth=%o stage=%o', this.scopeDepth, this.targetDepth, this.stage ? this.stage.name : undefined);
    this.scopeStack.push([this.scopeDepth, this.scopeTi, nextStage]);
    this.scopeDepth = this.targetDepth;
  }

  popScope() {
    if (!this.stage.canPop) {
      throw new PrePatchError();
    }
    let { scopeStack } = this;
    debug('popScope scopeStack=%o', scopeStack);
    if (scopeStack.length === 0) {
      throw new PrePatchError();
    }
    [this.scopeDepth, this.scopeTi, this.stage] = scopeStack.pop();
  }

  assignValue(value) {
    this.budgePending(false);
    try {
      this.target.assign(this.pendingKey, value);
    } catch (e) {
      throw PrePatchError(e);
    }
    this.assignValues = null;
  }

  startReplace() {
    return this.replaceValues = [];
  }

  addReplace(value) {
    return this.replaceValues.push(value);
  }

  commitReplace() {
    debug('commitReplace pendingKey=%o replaceValues=%o', this.pendingKey, this.replaceValues);
    if (this.replaceValues != null) {
      this.budgePending(false);
      this.target.replace(this.pendingKey, this.replaceValues);
      this.replaceValues = null;
    }
  }

  doUnset(key) {
    debug('doUnset key=%o', key);
    this.budgePending(false);
    this.target.unset(key);
  }

  doDelete(skey) {
    debug('doDelete skey=%o', skey);
    this.budgePending(true);
    let m = reRange.exec(skey);
    if (m == null) {
      throw new PrePatchError(`ill-formed range '${skey}'`);
    }
    let key = Number(m[1]);
    let len = (m[3] != null) ? Number(m[3]) + 1 : 1;
    this.target.delete(key, len);
  }

  continueModify() {
    let c = this.delta[++this.pos];
    let ti = this.getCurrentTi();
    debug('coninueModify c=%o', c);
    switch (c) {
      case '=':
        var expectedTi = TI_OBJECT;
        var stage = stages.assignBegin;
        break;
      case '-':
        expectedTi = TI_OBJECT;
        stage = stages.unsetBegin;
        break;
      case 'd':
        expectedTi = TI_ARRAY;
        stage = stages.deleteBegin;
        break;
      case 'i':
        expectedTi = TI_ARRAY;
        stage = stages.insertBegin;
        break;
      case 'm':
        expectedTi = TI_ARRAY;
        stage = stages.moveBegin;
        break;
      case 'r':
        expectedTi = TI_ARRAY;
        stage = stages.replaceBegin;
        break;
      case 's':
        expectedTi = TI_STRING;
        stage = stages.substituteBegin;
        break;
      default:
        throw new PrePatchError();
    }
    if (ti !== TI_UNKNOW && ti !== expectedTi) {
      let expectedName = (() => { switch (expectedTi) {
        case TI_ARRAY:
          return 'array';
        case TI_OBJECT:
          return 'object';
        case TI_STRING:
          return 'string';
        default:
          return 'scalar';
      } })();
      throw new PatchError(this.delta, this.pos, `can't patch ${this.target.get()} with ${expectedName} modifier`);
    }
    this.stage = stage;
    this.rawNext = true;
    this.skipNext = 1;
  }

  startModify(nextStage) {
    debug('startModify nextStage=%o', nextStage.name);
    this.budgePending(true);
    this.pushScope(nextStage);
    this.continueModify();
  }

  startInsert(skey) {
    if (!reIndex.test(skey)) {
      throw new PrePatchError(`non-numeric index ${skey} for array ${this.target.get ? this.target.get() : null}`);
    }
    this.insertKey = Number(skey);
    this.insertValues = [];
  }

  addInsert(value) {
    return this.insertValues.push(value);
  }

  commitInsert() {
    debug('commitInsert insertKey=%o, insertValues=%o', this.insertKey, this.insertValues);
    this.target.insert(this.insertKey, this.insertValues);
  }

  doMove(skey) {
    debug('doMove skey=%o', skey);
    let m = reMove.exec(skey);
    if (m == null) {
      throw new PrePatchError(`ill-formed move '${skey}'`);
    }
    let srcKey = Number(m[1]);
    if (m[3] != null) {
      var len = Number(m[3]) + 1;
      var reverse = m[2][0] === '-';
    } else {
      var len = 1;
      var reverse = false;
    }
    let dstKey = Number(m[4]);

    debug('doMove srcKey=%o dstKey=%o len=%o reverse=%o', srcKey, dstKey, len, reverse);
    this.target.move(srcKey, dstKey, len, reverse);
  }

  startSubstitute(skey) {
    this.substituteValues = [];
    this.addSubstitute(skey);
  }

  addSubstitute(skey) {
    let m = reSubst.exec(skey);
    if (m == null) {
      throw new PrePatchError(`invalid substitution ${skey} for string ${this.target.get ? this.target.get() : undefined}`);
    }
    let ofs = Number(m[1]);
    if (m[3] != null) {
      var lenDiff = Number(m[3]);
      if (m[2][0] === '-') {
        lenDiff = -lenDiff;
      }
    } else {
      var lenDiff = 0;
    }
    if (m[5] != null) {
      var str = m[5];
    } else {
      var str = '';
    }
    return this.substituteValues.push([ofs, lenDiff, str]);
  }

  commitSubstitute() {
    debug('commitSubstitute insertValues=%o', this.substituteValues);
    this.target.substitute(this.substituteValues);
  }
}


var stages = {
  assignBegin: {
    value(value) {
      this.enterObjectKey(value);
      this.stage = stages.assignHasKey;
    },
    ['#'](value) {
      this.enterObjectKey('');
      this.stage = stages.assignHasKey;
    }
  },
  assignHasKey: {
    ['|']() {
      this.stage = stages.assignBegin;
    },
    [':']() {
      this.rawNext = false;
      this.stage = stages.assignHasColon;
    },
    ['[']() {
      this.startModify(stages.assignHasModify);
    }
  },
  assignHasColon: {
    value(value) {
      this.assignValue(value);
      this.stage = stages.assignHasValue;
    }
  },
  assignHasValue: {
    ['|']() {
      this.resetPath();
      this.stage = stages.assignBegin;
    },
    [']']() {
      if (this.scopeStack.length === 0) {
        throw new PrePatchError();
      }
      this.stage = stages.modifyEnd;
    },
    end() {
      if (this.scopeStack.length > 0) {
        throw new PrePatchError();
      }
    }
  },
  assignHasModify: {
    ['|']() {
      this.resetPath();
      this.stage = stages.assignBegin;
    },
    [']']() {
      if (this.scopeStack.length === 0) {
        throw new PrePatchError();
      }
      this.stage = stages.modifyEnd;
    },
    end() {
      if (this.scopeStack.length > 0) {
        throw new PrePatchError();
      }
    }
  },

  replaceBegin: {
    value(value) {
      this.enterArrayKey(value);
      this.stage = stages.replaceHasKey;
    }
  },
  replaceNextKey: {
    value(value) {
      this.enterObjectKey(value);
      this.stage = stages.replaceHasKey;
    }
  },
  replaceHasKey: {
    ['|']() {
      this.stage = stages.replaceNextKey;
    },
    [':']() {
      this.rawNext = false;
      this.stage = stages.replaceHasColon;
      this.startReplace();
    },
    ['[']() {
      this.startModify(stages.replaceHasModify);
    }
  },
  replaceHasColon: {
    value(value) {
      this.addReplace(value);
      this.stage = stages.replaceHasValue;
    }
  },
  replaceHasValue: {
    [':']() {
      this.rawNext = false;
      this.stage = stages.replaceHasColon;
    },
    ['|']() {
      this.commitReplace();
      this.resetPath();
      this.stage = stages.replaceBegin;
    },
    [']']() {
      this.commitReplace();
      this.stage = stages.modifyEnd;
    }
  },
  replaceHasModify: {
    ['|']() {
      this.commitReplace();
      this.resetPath();
      this.stage = stages.replaceBegin;
    },
    [']']() {
      this.commitReplace();
      this.stage = stages.modifyEnd;
    }
  },

  unsetBegin: {
    value(value) {
      this.doUnset(value);
      this.stage = stages.unsetHas;
    },
    ['#']() {
      this.doUnset('');
      this.stage = stages.unsetHas;
    }
  },
  unsetHas: {
    [']']() {
      this.stage = stages.modifyEnd;
    },
    ['|']() {
      this.stage = stages.unsetBegin;
    }
  },

  deleteBegin: {
    value(value) {
      this.doDelete(value);
      this.stage = stages.deleteHas;
    },
    ['#']() {
      this.doDelete('');
      this.stage = stages.deleteHas;
    }
  },
  deleteHas: {
    [']']() {
      this.stage = stages.modifyEnd;
    },
    ['|']() {
      this.stage = stages.deleteBegin;
    }
  },

  insertBegin: {
    value(value) {
      this.startInsert(value);
      this.stage = stages.insertHasKey;
    }
  },
  insertHasKey: {
    [':']() {
      this.stage = stages.insertHasColon;
      this.rawNext = false;
    }
  },
  insertHasColon: {
    value(value) {
      this.addInsert(value);
      this.stage = stages.insertHasValue;
    }
  },
  insertHasValue: {
    [':']() {
      this.stage = stages.insertHasColon;
      this.rawNext = false;
    },
    ['|']() {
      this.commitInsert();
      this.stage = stages.insertBegin;
    },
    [']']() {
      this.commitInsert();
      this.stage = stages.modifyEnd;
    }
  },

  moveBegin: {
    value(value) {
      this.doMove(value);
      this.stage = stages.moveHas;
    }
  },
  moveHas: {
    [']']() {
      this.stage = stages.modifyEnd;
    },
    ['|']() {
      this.stage = stages.moveBegin;
    }
  },

  substituteBegin: {
    value(value) {
      this.startSubstitute(value);
      this.stage = stages.substituteHas;
    }
  },
  substituteHas: {
    [']']() {
      this.commitSubstitute();
      this.stage = stages.modifyEnd;
    },
    ['|']() {
      this.stage = stages.substituteNext;
    }
  },
  substituteNext: {
    value(value) {
      this.addSubstitute(value);
      this.stage = stages.substituteHas;
    }
  },


  modifyEnd: {
    canPop: true,
    ['[']() {
      this.resetPath();
      return this.continueModify();
    }
  },

  patchBegin: {
    value(value) {
      this.enterObjectKey(value);
      this.stage = stages.assignHasKey;
    },
    ['#'](value) {
      this.enterObjectKey('');
      this.stage = stages.assignHasKey;
    },
    ['[']() {
      this.startModify(stages.patchHasModify);
    }
  },

  patchHasModify: {
    value(value) {
      this.enterObjectKey(value);
      this.stage = stages.assignHasKey;
    },
    ['#'](value) {
      this.enterObjectKey(value);
      this.stage = stages.assignHasKey;
    },
    end() {
      if (this.scopeStack.length > 0) {
        throw new PrePatchError();
      }
    }
  }
};

{
  for (let name in stages) {
    let stage = stages[name];
    stage.name = name;
  }  
};


class Patcher {

  constructor(wdiff, options) {
    this.wdiff = wdiff;
  }

  patchTarget(target, delta) {
    debug('patch: target=%o, delta=%o', target, delta);
    if (delta == null) {
      return;
    }
    try {
      if (delta[0] !== '|') {
        let value = this.wdiff.WSON.parse(delta);
        target.assign(null, value);
      } else {
        var state = new State(this.wdiff.WSON, delta, 1, target, stages.patchBegin);
        this.wdiff.WSON.parsePartial(delta, {
          howNext: [true, 1],
          cb(isValue, value, nextPos) {
            while (true) {
              let { stage } = state;
              debug('patch: stage=%o, isValue=%o, value=%o, nextPos=%o', stage.name, isValue, value, nextPos);
              if (isValue) {
                var handler = stage.value;
              } else {
                var handler = stage[value];
              }
              debug('patch: handler=%o', handler);
              if (handler) {
                break;
              }
              state.popScope();
            }
            state.rawNext = true;
            state.skipNext = 0;
            handler.call(state, value, nextPos);
            debug('patch: pos=%o, rawNext=%o, skipNext=%o, stage.name=%o', state.pos, state.rawNext, state.skipNext, state.stage ? state.stage.name : undefined);
            state.pos = nextPos;
            if (state.skipNext > 0) {
              state.pos += state.skipNext;
              return [state.rawNext, state.skipNext];
            } else {
              return state.rawNext;
            }
          },
          backrefCb: (target.get != null) ?
            refIdx => target.get(refIdx)
          :
            null
        }
        );

        state.pos = delta.length;
        while (true) {
          debug('patch: done: stage=%o', state.stage.name);
          var handler = state.stage.end;
          if (handler) {
            break;
          }
          state.popScope();
        }
        handler.call(state);
      }

      target.done();
      return;

    } catch (error) {
      if (error.name === 'PrePatchError') {
        throw new PatchError(delta, state.pos, error.cause);
      } else if (error.name === 'ParseError') {
        throw new PatchError(error.s, error.pos, error.cause);
      } else {
        throw error;
      }
    }
  }

  patch(value, delta, notifiers) {
    let target = new ValueTarget(this.wdiff.WSON, value);

    if (notifiers != null) {
      if (notifiers.constructor !== Array) {
        notifiers = [notifiers];
      }
      if (notifiers.length > 0) {
        target.setSubTarget(new NotifierTarget(target, notifiers));
      }
    }
        
    this.patchTarget(target, delta);

    target.setSubTarget(null);
    return target.getRoot();
  }
}


export { Patcher,  PatchError };

