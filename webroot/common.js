/* StrongBox — shared WebUI helpers.
 *
 * Load before a page's own script:
 *   <script src="../common.js"></script>
 *
 * Provides a single shell bridge so pages stop re-implementing the
 * KernelSU / KernelSU-Next / iframe-parent plumbing. New pages should call
 * SB.exec() / SB.execAsync() instead of hand-rolling `ksu.exec`.
 */
(function (w) {
  "use strict";
  var SB = w.SB || {};

  // Run a shell command through whichever bridge is available. Returns
  // whatever the host returns: KernelSU's ksu.exec is synchronous, while the
  // iframe parent bridge is a Promise. Use execAsync() when you want await.
  SB.exec = function (cmd) {
    try { if (w.ksu && typeof w.ksu.exec === "function") return w.ksu.exec(cmd); } catch (e) {}
    try { if (w.kernelsu && typeof w.kernelsu.exec === "function") return w.kernelsu.exec(cmd); } catch (e) {}
    try {
      if (w.parent && w.parent !== w && typeof w.parent.runShellFromIframe === "function") {
        return w.parent.runShellFromIframe(cmd);
      }
    } catch (e) {}
    return "";
  };

  // Promise-flavoured wrapper (always resolves a string).
  SB.execAsync = function (cmd) {
    var r = SB.exec(cmd);
    return (r && typeof r.then === "function") ? r : Promise.resolve(r == null ? "" : r);
  };

  // The hosting iframe's parent window, or null when opened standalone.
  SB.parentFrame = function () {
    try { return w.parent && w.parent !== w ? w.parent : null; } catch (e) { return null; }
  };

  w.SB = SB;
})(window);