TARGET = iphone:clang:latest:15.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollWebInspector

TrollWebInspector_FILES = AuxiliaryExecute.swift AuxiliaryExecute+Spawn.swift Execute.swift ContentView.swift TrollWebInspectorApp.swift pid_utils.m 
TrollWebInspector_FRAMEWORKS = SwiftUI
TrollWebInspector_CFLAGS = -fobjc-arc
TrollWebInspector_SWIFT_BRIDGING_HEADER = TrollWebInspector-Bridging-Header.h
TrollWebInspector_CODESIGN_FLAGS = -TrollWebInspector.entitlements

include $(THEOS_MAKE_PATH)/application.mk
