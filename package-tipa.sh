#!/bin/bash
make clean
FINALPACKAGE=1 make package ARCHS=arm64

rm -rf Payload TrollWebInspector.tipa
mkdir Payload
cp -r .theos/obj/TrollWebInspector.app Payload/
cp Info.plist Payload/TrollWebInspector.app/Info.plist

if [ -f "injector" ] && [ -f "agent.dylib" ] ; then
    echo "[*] Copying injector and agent.dylib..."
    cp injector Payload/TrollWebInspector.app/
    cp agent.dylib Payload/TrollWebInspector.app/

else
    echo "[-] ERROR: 'injector' or 'agent.dylib' missing in project root!"
    exit 1
fi

cp cp Payload/TrollWebInspector.app/
cp cp-15 Payload/TrollWebInspector.app/
cp chown Payload/TrollWebInspector.app/
cp libiosexec.1.dylib Payload/TrollWebInspector.app/
cp libintl.8.dylib Payload/TrollWebInspector.app/
cp libxar.1.dylib Payload/TrollWebInspector.app/
cp libcrypto.3.dylib Payload/TrollWebInspector.app/

chmod 755 Payload/TrollWebInspector.app/TrollWebInspector
chmod 755 Payload/TrollWebInspector.app/injector
chmod 755 Payload/TrollWebInspector.app/cp
chmod 755 Payload/TrollWebInspector.app/cp-15
chmod 755 Payload/TrollWebInspector.app/chown
chmod 755 Payload/TrollWebInspector.app/libiosexec.1.dylib
chmod 755 Payload/TrollWebInspector.app/agent.dylib
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/cp
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/cp-15
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/libiosexec.1.dylib
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/libintl.8.dylib
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/libxar.1.dylib
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/libcrypto.3.dylib
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/chown
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/agent.dylib
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/injector
./ldid -STrollWebInspector.entitlements Payload/TrollWebInspector.app/TrollWebInspector

zip -r TrollWebInspector.tipa Payload