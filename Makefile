TARGET = iphone:clang:latest:15.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = RootHelper
RootHelper_FILES = main.m
RootHelper_CFLAGS = -fobjc-arc -O2 -Wall
RootHelper_LDFLAGS = -lresolv -Wl,-framework,Foundation
RootHelper_CODESIGN_FLAGS = -STrollWebInspector.entitlements
RootHelper_INSTALL_PATH = /Applications/TrollWebInspector.app

APPLICATION_NAME = TrollWebInspector

TrollWebInspector_FILES = RootExecutor.swift AuxiliaryExecute.swift AuxiliaryExecute+Spawn.swift Execute.swift ContentView.swift TrollWebInspectorApp.swift pid_utils.m 
TrollWebInspector_FRAMEWORKS = SwiftUI
TrollWebInspector_CFLAGS = -fobjc-arc
TrollWebInspector_SWIFT_BRIDGING_HEADER = TrollWebInspector-Bridging-Header.h
TrollWebInspector_CODESIGN_FLAGS = -TrollWebInspector.entitlements

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk
