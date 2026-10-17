# ГЛАС — iPhone demo app

## Run on your iPhone 15
1. Unzip, then double-click **GLAS.xcodeproj** (not ContentView.swift). Needs Xcode 16 or newer on a Mac.
2. Click the blue **GLAS** project icon, then **TARGETS > GLAS > Signing & Capabilities**.
3. Tick **Automatically manage signing** and pick your Apple ID under **Team** (Personal Team is fine).
4. If Xcode says the Bundle Identifier is taken, change `com.burakismail.glas` to anything unique.
5. Plug in and unlock the iPhone, tap **Trust**. In **Settings > Privacy & Security > Developer Mode**, turn it on (the phone restarts).
6. Pick your iPhone in the top toolbar and press **Command + R**.
7. First launch: **Settings > General > VPN & Device Management**, trust your developer profile.

Requires iOS 17.0 or newer. To test without a phone, choose any iPhone simulator.

Features: map, demo safety alerts, private local reports, profile, nearest police station lookup via Apple Maps, three-second SOS alarm.

**Safety:** This is a prototype. SOS does not contact police or emergency responders. Demo alerts are fictional. In a real emergency in North Macedonia, call 112.
