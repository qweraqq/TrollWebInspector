#!/bin/bash
make clean
FINALPACKAGE=1 make package ARCHS=arm64

rm -rf Payload TrollWebInspector.tipa
mkdir Payload
cp -r .theos/obj/TrollWebInspector.app Payload/
cp Info.plist Payload/TrollWebInspector.app/Info.plist

if [ -f "injector" ] && [ -f "agent.dylib" ]; then
    echo "[*] Copying injector and agent.dylib..."
    cp injector Payload/TrollWebInspector.app/
    cp agent.dylib Payload/TrollWebInspector.app/
else
    echo "[-] ERROR: 'injector' or 'agent.dylib' missing in project root!"
    exit 1
fi

chmod 755 Payload/TrollWebInspector.app/TrollWebInspector
chmod 755 Payload/TrollWebInspector.app/injector
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/TrollWebInspector

zip -r TrollWebInspector.tipa Payload