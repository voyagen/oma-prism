import QtQuick

// Acceptance-only entry point. Never included in a production installation.
Bar {
  id: developmentBar
  Smoke { bar: developmentBar }
  SmokeLayout { bar: developmentBar }
  SmokeSettings { bar: developmentBar; panel: developmentBar.settingsPanel }
}
