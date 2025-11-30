#!/bin/bash
make clean
FINALPACKAGE=1 make package ARCHS=arm64
cp .theos/obj/agent.dylib .theos/obj/TrollWebInspector.app/
cp .theos/obj/helper .theos/obj/TrollWebInspector.app/
# cp .theos/obj/injector .theos/obj/TrollWebInspector.app/

rm -rf Payload TrollWebInspector.tipa
mkdir Payload
cp -r .theos/obj/TrollWebInspector.app Payload/
cp Info.plist Payload/TrollWebInspector.app/Info.plist
# chmod +x Payload/TrollWebInspector.app/injector
# ./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/injector
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/helper
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/agent.dylib

chmod 755 Payload/TrollWebInspector.app/TrollWebInspector
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/TrollWebInspector

zip -r TrollWebInspector.tipa Payload