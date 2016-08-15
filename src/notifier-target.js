let debug = require('debug')('wson-diff:notifier-target');

class NotifierTarget {

  constructor(vt, notifiers) {
    this.vt        = vt;
    this.notifiers = notifiers;
    let { current } = vt;
    let depths = [];
    for (let ndx = 0; ndx < notifiers.length; ndx++) {
      let notifier = notifiers[ndx];
      depths[ndx] = false === notifier.checkedBudge(0, null, current) ?
        0 // assign root
      :
        null;
    }
    this.depths = depths;    
  }

  budge(up, key) {
    let { vt } = this;
    let { depths } = this;
    let { stack } = vt;
    let { current } = vt;
    let stackLen = stack.length;
    let newLen = stackLen - up;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      let notifyDepth = depths[ndx];
      if (up > 0) {
        if (notifyDepth != null) {
          var notifyUp = notifyDepth - newLen;
          if (notifyUp > 0) {
            let notifyValue = notifyDepth === stackLen ?
              current
            :
              stack[notifyDepth];
            notifier.assign(null, notifyValue);
            notifyDepth = null;
          } else {
            notifyUp = 0;
          }
        } else {
          var notifyUp = up;
        }
      } else {
        var notifyUp = 0;
      }
      debug('budge: notifyUp=%o', notifyUp);
      if (key != null) {
        if (notifyDepth == null) {
          if (false === notifier.checkedBudge(notifyUp, key, current)) {
            notifyDepth = newLen + 1;
          }
        }
      } else if (notifyUp > 0) {
        notifier.checkedBudge(notifyUp, null, current);
      }
      debug('budge: ->notifyDepth=%o', notifyDepth);
      depths[ndx] = notifyDepth;
    }  
  }


  unset(key) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.unset(key, current);
      }
    }  
  }

  assign(key, value) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.assign(key, value, current);
      }
    }  
  }

  delete(idx, len) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.delete(idx, len, current);
      }
    }  
  }

  move(srcIdx, dstIdx, len, reverse) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.move(srcIdx, dstIdx, len, reverse, current);
      }
    }  
  }

  insert(idx, values) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.insert(idx, values, current);
      }
    }  
  }

  replace(idx, values) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.replace(idx, values, current);
      }
    }  
  }

  substitute(patches) {
    let { depths } = this;
    let { current } = this.vt;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      if (depths[ndx] == null) {
        notifier.substitute(patches, current);
      }
    }  
  }

  done() {
    let { depths } = this;
    let { current } = this.vt;
    let { stack } = this.vt;
    debug('done: stack=%o current=%o depths=%o', stack, current, depths);
    let stackLen = stack.length;
    for (let ndx = 0; ndx < this.notifiers.length; ndx++) {
      let notifier = this.notifiers[ndx];
      let notifyDepth = depths[ndx];
      if (notifyDepth != null) {
        let notifyValue = notifyDepth === stackLen ?
          current
        :
          stack[notifyDepth];
        debug('done: ndx=%o value=%o', ndx, notifyValue);
        notifier.assign(null, notifyValue);
      }
    }  
  }
}


export default NotifierTarget;


