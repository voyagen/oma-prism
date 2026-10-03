// Acceptance data, independent of the runtime catalogue/stem table.
module.exports = {
  'omarchy.audio': [['','volume-muted'],['󰋋','headphones'],['','volume-low'],['','volume-medium'],['','volume-high']],
  'omarchy.network': [['󰤯','wifi-signal-0'],['󰤟','wifi-signal-1'],['󰤢','wifi-signal-2'],['󰤥','wifi-signal-3'],['󰤨','wifi-signal-4'],['󰈀','ethernet'],['󰤮','network-disconnected']],
  'omarchy.bluetooth': [['󰂲','bluetooth-off'],['󰂱','bluetooth-connected'],['󰂯','bluetooth-enabled']],
  'omarchy.power': [
    ...['󰁺','󰁻','󰁼','󰁽','󰁾','󰁿','󰂀','󰂁','󰂂','󰁹'].map((glyph,i)=>[glyph,`battery-level-${i}`]),
    ...['󰢜','󰂆','󰂇','󰂈','󰢝','󰂉','󰢞','󰂊','󰂋','󰂅'].map((glyph,i)=>[glyph,`battery-charging-level-${i}`])
  ],
  'omarchy.monitor': [['󰍹','display'],['󰍺','displays-multiple']],
  'omarchy.microphone': [['󰍭','microphone-muted'],['󰍬','microphone-enabled']],
  'omarchy.weather': [['','weather-clear-day'],['','weather-clear-night'],['','weather-partly-cloudy-day'],['','weather-partly-cloudy-night'],['','weather-cloudy'],['\uE313','weather-fog-day'],['\uE346','weather-fog-night'],['','weather-showers-day'],['','weather-showers-night'],['','weather-snow-showers-day'],['','weather-snow-showers-night'],['','weather-sleet'],['','weather-thunderstorm'],['','weather-rain'],['','weather-snow']],
  Dnd: [['󰂛','notifications-silenced']], NightLight: [['󰔎','night-light']], StayAwake: [['󰅶','stay-awake']], Reminder: [['󰢌','reminder']], ScreenRecording: [['󰻂','screen-recording']], Dictation: [['󰍬','dictation'],['󰔟','dictation-transcribing']],
  'omarchy.system-update': [['\uF021','system-update']],
  'omarchy.agents': [[String.fromCodePoint(0xF16A3),'agents']],
  'omarchy.tray': [['\uF053','tray-drawer-chevron']],
  'jrmmhm.pocket': [[String.fromCodePoint(0xF01D8),'drawer-chevron']],
  omaplug: [[String.fromCodePoint(0xF14D3),'plugin-manager-open'],[String.fromCodePoint(0xF14D9),'plugin-manager-closed']],
  'njpatel.omaherdr': [[0xF06A9,'robot'],[0xF1719,'robot-happy'],[0xF018D,'console'],[0xF0489,'terminal'],[0xF09D1,'brain'],[0xF000E,'users'],[0xF056E,'dashboard'],[0xF023B,'flag'],[0xF009A,'bell'],[0xF048B,'server'],[0xF0317,'lan'],[0xF061A,'cpu'],[0xF0430,'activity']].map(([cp,semantic])=>[String.fromCodePoint(cp),semantic])
};
