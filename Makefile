TARGET = iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES = TrollWebInspector

include $(THEOS)/makefiles/common.mk

# --- Config ---
FRIDA_VERSION := 17.5.1
FRIDA_ARCH := ios-arm64

# --- Download Frida Devkits ---
setup-frida:
	@echo "Checking for Frida Devkits..."
	@if [ ! -d "frida-core" ]; then \
		echo "Downloading frida-core..."; \
		curl -Ls https://github.com/frida/frida/releases/download/$(FRIDA_VERSION)/frida-core-devkit-$(FRIDA_VERSION)-$(FRIDA_ARCH).tar.xz | tar -xJ -C . -f - --one-top-level=frida-core; \
	fi
	@if [ ! -d "frida-gum" ]; then \
		echo "Downloading frida-gum..."; \
		curl -Ls https://github.com/frida/frida/releases/download/$(FRIDA_VERSION)/frida-gum-devkit-$(FRIDA_VERSION)-$(FRIDA_ARCH).tar.xz | tar -xJ -C . -f - --one-top-level=frida-gum; \
	fi

# --- Agent (The Dylib injected into webinspectord) ---
LIBRARY_NAME = agent
agent_FILES = agent.c
agent_CFLAGS = -Ifrida-gum -Os
agent_LDFLAGS = -Lfrida-gum -lfrida-gum -framework CoreFoundation -framework Security -Wl,-dead_strip
agent_INSTALL_PATH = /Applications/TrollWebInspector.app

# # --- Injector (The CLI tool) ---
# TOOL_NAME = injector
# injector_FILES = injector.c
# injector_CFLAGS = -Ifrida-core -Os
# injector_LDFLAGS = -Lfrida-core -lfrida-core -lresolv -Wl,-framework,Foundation,-framework,UIKit,-dead_strip
# injector_CODESIGN_FLAGS = -STrollWebInspector.entitlements
# injector_INSTALL_PATH = /Applications/TrollWebInspector.app

# --- Helper (The Root Tool) ---
TOOL_NAME = helper
helper_FILES = helper.c
helper_CFLAGS = -Wall -pipe -Ifrida-core -Os
# Helper needs Frida Core to inject, and standard frameworks
helper_LDFLAGS = -Lfrida-core -lfrida-core -lresolv -lobjc -Wl,-framework,Foundation,-framework,UIKit -Wl,-dead_strip
helper_FRAMEWORKS = Foundation
helper_INSTALL_PATH = /Applications/TrollWebInspector.app

# --- App (The UI) ---
APPLICATION_NAME = TrollWebInspector

TrollWebInspector_FILES = AuxiliaryExecute.swift AuxiliaryExecute+Spawn.swift Execute.swift ContentView.swift TrollWebInspectorApp.swift 
TrollWebInspector_FRAMEWORKS = SwiftUI
TrollWebInspector_CODESIGN_FLAGS = -TrollWebInspector.entitlements
TrollWebInspector_CFLAGS = -Ifrida-core -Os
TrollWebInspector_LDFLAGS = -Lfrida-core -lfrida-core -lresolv -Wl,-framework,Foundation,-framework,UIKit,-dead_strip

# --- Build Rules ---
before-all:: setup-frida

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/application.mk
