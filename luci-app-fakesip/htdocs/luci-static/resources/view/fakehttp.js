"use strict";
"require view";
"require form";
"require uci";
"require tools.widgets as widgets";

const conf = "fakesip";
const instance = "fakesip";

return view.extend({
  load: function () {
    return Promise.all([uci.load(conf)]);
  },
  render: function (res) {
    let m, s, o;

    m = new form.Map(
      "fakesip",
      _("fakesip"),
      _("Obfuscate all your UDP connections into SIP protocol.")
    );

    // General Settings
    s = m.section(form.TypedSection, "globals", _("General Settings"));
    s.anonymous = true;

    o = s.option(form.Flag, "enabled", _("Enable"));
    o.default = 0;
    o.rmempty = false;

    o = s.option(form.Flag, "silent", _("Enable silent mode"));
    o.default = 1;
    o.rmempty = false;

    o = s.option(
      widgets.DeviceSelect,
      "interface",
      _("Interfaces"),
      _("work on specified network interface")
    );
    o.multiple = true;
    o.nocreate = true;
    o.rmempty = false;

    // Payload Settings
    s = m.section(form.GridSection, "payload", _("Payload Settings"));
    s.addremove = true;
    s.anonymous = true;
    s.sortable = true;
    s.nodescriptions = true;

    o = s.option(form.Flag, "enabled", _("Enable"));
    o.default = 0;
    o.editable = true;
    o.rmempty = false;

    o = s.option(form.ListValue, "type", _("Type"));
    o.value("sip_uri", "SIP_URI");
    o.value("binary", "Binary");
    o.editable = true;
    o.rmempty = false;

    o = s.option(form.Value, "payload", _("Payload"));
    o.editable = true;
    o.rmempty = false;

    o = s.option(form.Value, "comment", _("Comment"));
    o.editable = true;
    o.default = "";

    return m.render();
  },
});
