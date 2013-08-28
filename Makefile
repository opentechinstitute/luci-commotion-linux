include build/config.mk

#MODULES = contrib/* applications/* libs/* modules/* themes/* i18n/*
MODULES = contrib/lar contrib/luasrcdiet contrib/uci contrib/uhttpd libs/* modules/admin-core modules/commotion themes/base themes/commotion

OS:=$(shell uname)
MODULES:=$(foreach item,$(wildcard $(MODULES)),$(if $(realpath $(wildcard $(item)/Makefile)),$(item)))

BUILD_DIR = /tmp/host
FINAL_INSTALL_DIR=/opt/luci-commotion
INSTALL_DIR = $(DESTDIR)$(FINAL_INSTALL_DIR)
BIN = $(DESTDIR)/usr/sbin
FINAL_LIB=/usr/lib
LIB = $(DESTDIR)$(FINAL_LIB)

export OS

.PHONY: all build gccbuild luabuild clean host gcchost luahost hostcopy hostclean

all: build

build: gccbuild luabuild

gccbuild:
	make -C libs/web CC="cc" CFLAGS="" LDFLAGS="" SDK="$(shell test -f .running-sdk && echo 1)" host-install
	for i in $(MODULES); do \
		make -C$$i SDK="$(shell test -f .running-sdk && echo 1)" compile || { \
			echo "*** Compilation of $$i failed!"; \
			exit 1; \
		}; \
	done

#luabuild: i18nbuild
luabuild:
	for i in $(MODULES); do HOST=$(BUILD_DIR) \
		SDK="$(shell test -f .running-sdk && echo 1)" make -C$$i luabuild; done

i18nbuild:
	mkdir -p $(BUILD_DIR)/lua-po
	./build/i18n-po2lua.pl ./po $(BUILD_DIR)/lua-po

clean:
	rm -f .running-sdk uhttpd
	rm -rf docs
	rm -rf $(BUILD_DIR)
	#make -C libs/lmo host-clean
	for i in $(MODULES); do make -C$$i clean; done


host: build hostcopy

gcchost: gccbuild hostcopy

luahost: luabuild hostcopy

hostcopy: 
	mkdir -p $(BUILD_DIR)/tmp
	mkdir -p $(BUILD_DIR)/var/state
	for i in $(MODULES); do cp -pR $$i/dist/* $(BUILD_DIR)/ 2>/dev/null || true; done
	for i in $(MODULES); do cp -pR $$i/hostfiles/* $(BUILD_DIR)/ 2>/dev/null || true; done
	rm -f $(BUILD_DIR)/luci
	ln -s .$(LUCI_MODULEDIR) $(BUILD_DIR)/luci
	rm -rf /tmp/luci-* || true

hostenv: sdk host ucidefaults

sdk:
	touch .running-sdk

ucidefaults:
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "$(BUILD_DIR)/bin/uci-defaults --exclude luci-freifunk-*"

httpd: hostenv
	install -d $(BUILD_DIR)
	cp $(realpath build)/lucid.lua $(BUILD_DIR)/bin/lucid.lua
	cp $(realpath build)/setup.lua $(BUILD_DIR)/bin/setup.lua
	sed -i -e 's|build|'$(FINAL_INSTALL_DIR)'/bin|' $(BUILD_DIR)/bin/lucid.lua
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "uci set lucid.webroot.physical=$(FINAL_INSTALL_DIR)/www"
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "uci commit lucid"
	#build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "lua build/lucid.lua"

runhttpd: hostenv
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "uci set lucid.webroot.physical=$(BUILD_DIR)/www"
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "uci commit lucid"
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "lua build/lucid.lua"

uhttpd: hostenv
	install -d $(BUILD_DIR)
	cp $(realpath build)/luci.cgi $(BUILD_DIR)/www/cgi-bin/luci
	cp $(realpath build)/setup.lua $(BUILD_DIR)/bin/setup.lua
	sed -i -e 's|../../build|'$(FINAL_INSTALL_DIR)'/bin|' $(BUILD_DIR)/www/cgi-bin/luci
	#build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "$(BUILD_DIR)/usr/sbin/uhttpd -p 8080 -h $(BUILD_DIR)/www -f"

runuhttpd:
	build/hostenv.sh $(realpath $(INSTALL_DIR)) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "$(realpath $(INSTALL_DIR))/usr/sbin/uhttpd -p 8080 -h $(realpath $(INSTALL_DIR))/www -f"

install: uhttpd
	install -d $(INSTALL_DIR) $(BIN) $(LIB)
	mv $(BUILD_DIR)/* $(INSTALL_DIR)
	install $(realpath build)/luci $(BIN)
	install -m0644 $(INSTALL_DIR)/usr/lib/libuci.so.0.8 $(LIB)
	ln -sf $(FINAL_LIB)/libuci.so.0.8 $(LIB)/libuci.so

uninstall:
	rm -rf $(INSTALL_DIR)
	rm -f $(BIN)/luci
	rm -f $(LIB)/libuci*

runlua: hostenv
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "lua -i build/setup.lua"

runshell: hostenv
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) $$SHELL

hostclean: clean
	rm -rf $(BUILD_DIR)

apidocs: hostenv
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "build/makedocs.sh $(BUILD_DIR)/luci/ docs"

nixiodocs: hostenv
	build/hostenv.sh $(BUILD_DIR) $(LUA_MODULEDIR) $(LUA_LIBRARYDIR) "build/makedocs.sh libs/nixio/ nixiodocs"

po: host
	for L in $${LANGUAGE:-$$(find i18n/ -path 'i18n/*/luasrc/i18n/*' -name 'default.*.lua' | \
	  sed -e 's!.*/default\.\(.*\)\.lua!\1!')}; do \
	    build/i18n-lua2po.pl . $(BUILD_DIR)/po $$L; \
	done

run:
	#	make run is deprecated				#
	#	Please use:					#
	#							#
	#	To run LuCI WebUI using LuCIttpd		#
	#	make runhttpd					#
	#							#
	#	To run LuCI WebUI using Boa/Webuci		#
	#	make runboa 					#
	#							#
	#	To start a shell in the LuCI environment	#
	#	make runshell					#
	#							#
	#	To run Lua CLI in the LuCI environment		#
	#	make runlua					#
