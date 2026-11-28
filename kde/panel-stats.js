// Executed in Plasma's desktop scripting engine. mode is supplied by the wrapper.
const face = "org.example.installers.compactstats.cores";
const plugin = "org.kde.plasma.systemmonitor.cpu";
const ids = ["cpu/all/usage", "memory/physical/applicationPercent", "network/all/download", "network/all/upload"];
const candidates = panels().filter(p => p.location === "bottom");
if (candidates.length !== 1) throw new Error("Expected one bottom panel; found " + candidates.length);
const panel = candidates[0];
const monitors = panel.widgets().filter(w => w.type === plugin);
if (monitors.length > 1) throw new Error("Multiple CPU monitors; refusing to choose");
let widget = monitors[0];
if (widget) {
    widget.currentConfigGroup = ["Appearance"];
    const oldFace = widget.readConfig("chartFace", "");
    widget.currentConfigGroup = ["Sensors"];
    const previous = JSON.parse(widget.readConfig("highPrioritySensorIds", "[]"));
    if (oldFace !== face &&
        !(["org.example.installers.compactstats", "org.kde.ksysguard.textonly"].includes(oldFace) && JSON.stringify(previous) === JSON.stringify(ids)))
        throw new Error("Existing CPU monitor is not the known Compact Stats configuration");
}
const groups = {
    Appearance: {chartFace: face, title: "Total CPU Use", showTitle: false, updateRateLimit: 1000},
    Sensors: {highPrioritySensorIds: JSON.stringify(ids), lowPrioritySensorIds: "[]", totalSensors: JSON.stringify([ids[0]])},
    SensorLabels: {[ids[0]]: "CPU", [ids[1]]: "RAM", [ids[2]]: "\u2193", [ids[3]]: "\u2191"},
    SensorColors: {[ids[0]]: "56,169,217", [ids[1]]: "117,183,152", [ids[2]]: "167,139,250", [ids[3]]: "167,139,250"}
};
if (!widget && mode !== "apply") {
    print("COMPACT_STATS_DRIFT: missing widget");
} else {
    let created = false;
    if (!widget) {
        const trays = panel.widgets().filter(w => w.type === "org.kde.plasma.systemtray");
        const index = trays.length === 1 ? trays[0].index : -1;
        widget = panel.addWidget(plugin);
        if (!widget) throw new Error("Could not create CPU monitor");
        if (index >= 0) widget.index = index;
        created = true;
    }
    let changed = 0;
    for (const group of Object.keys(groups)) {
        widget.currentConfigGroup = [group];
        for (const key of Object.keys(groups[group])) {
            const value = groups[group][key];
            if (String(widget.readConfig(key, "__missing__")) === String(value)) continue;
            changed++;
            if (mode === "apply") widget.writeConfig(key, value);
        }
    }
    if (mode === "apply" && (changed || created)) widget.reloadConfig();
    print((mode !== "apply" && changed ? "COMPACT_STATS_DRIFT" : "COMPACT_STATS_OK") + ": " + changed + " settings differ" + (created ? "; widget created" : ""));
}
