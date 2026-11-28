// Offline model of the small Plasma scripting API used by panel-stats.js.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const code = fs.readFileSync(require('node:path').join(__dirname, '../kde/panel-stats.js'), 'utf8');
const plugin = 'org.kde.plasma.systemmonitor.cpu';
function widget(type, index, config = {}) {
    return {type, index, config, writes: 0, reloads: 0,
        readConfig(k, fallback) { return this.config[this.currentConfigGroup[0]]?.[k] ?? fallback; },
        writeConfig(k,v) { (this.config[this.currentConfigGroup[0]] ??= {})[k] = v; this.writes++; },
        reloadConfig() { this.reloads++; }};
}
const tray = widget('org.kde.plasma.systemtray', 3);
const other = widget('org.kde.plasma.digitalclock', 4);
const list = [tray, other];
const panel = {location:'bottom', widgets: () => list, addWidget(type) { const w = widget(type, list.length); list.push(w); return w; }};
function run(mode, ps = [panel]) {
    let result = '';
    vm.runInNewContext(code, {mode, panels: () => ps, print: s => { result += s; }});
    return result;
}
assert.match(run('check'), /DRIFT.*missing/);
assert.equal(list.length, 2);
assert.match(run('apply'), /OK.*created/);
const monitor = list[2];
assert.equal(monitor.index, 3);
assert.equal(monitor.config.Appearance.chartFace, 'org.example.installers.compactstats.cores');
assert.equal(monitor.config.SensorLabels['network/all/download'], '\u2193');
assert.equal(monitor.config.Sensors.lowPrioritySensorIds, '[]');
assert.equal(monitor.reloads, 1);
assert.equal(tray.writes + other.writes, 0);
const writes = monitor.writes;
assert.match(run('check'), /OK/);
assert.match(run('apply'), /OK: 0/);
assert.equal(monitor.writes, writes);
assert.equal(monitor.reloads, 1);
monitor.config.Appearance.showTitle = true;
assert.match(run('check'), /DRIFT/);
assert.equal(monitor.config.Appearance.showTitle, true);
assert.match(run('apply'), /OK/);
assert.equal(monitor.config.Appearance.showTitle, false);
monitor.config.Appearance.chartFace = 'org.example.installers.compactstats';
assert.match(run('apply'), /OK/);
monitor.config.Appearance.chartFace = 'unrelated';
assert.throws(() => run('apply'), /not the known/);
assert.equal(monitor.config.Appearance.chartFace, 'unrelated');
assert.throws(() => run('apply', [panel, panel]), /Expected one/);
list.push(widget(plugin, 6));
assert.throws(() => run('apply'), /Multiple CPU/);
console.log('kde-panel-stats JS: ok');
