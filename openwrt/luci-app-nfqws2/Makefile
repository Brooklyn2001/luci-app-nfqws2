include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nfqws2
PKG_VERSION:=$(shell cat ../../VERSION 2>/dev/null || echo "1.0.0")
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-nfqws2
  TITLE:=LuCI support for NFQWS2
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  DEPENDS:=+luci-base +nfqws2-keenetic
  PKGARCH:=all
  URL:=https://github.com/nfqws2/nfqws2-openwrt
endef

define Package/luci-app-nfqws2/description
  LuCI interface for NFQWS2 DPI bypass system.
endef

define Build/Prepare
	$(Build/Prepare/Default)
endef

define Build/Compile
	# No compilation needed
endef

define Package/luci-app-nfqws2/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/src/root/etc/init.d/nfqws2 $(1)/etc/init.d/nfqws2
	$(INSTALL_DIR) $(1)/etc/config
	$(CP) $(CURDIR)/src/root/etc/config/nfqws2 $(1)/etc/config/nfqws2
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) $(CURDIR)/src/root/usr/lib/lua/luci/controller/nfqws2.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/nfqws2
	$(CP) $(CURDIR)/src/root/usr/lib/lua/luci/view/nfqws2/index.htm $(1)/usr/lib/lua/luci/view/nfqws2/
	$(INSTALL_DIR) $(1)/usr/share/ucode/luci/controller
	$(CP) $(CURDIR)/src/ucode/controller/*.uc $(1)/usr/share/ucode/luci/controller/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(CP) $(CURDIR)/src/root/usr/share/rpcd/acl.d/*.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/apk/triggers
	$(INSTALL_BIN) $(CURDIR)/src/root/usr/share/apk/triggers/luci-app-nfqws2 $(1)/usr/share/apk/triggers/luci-app-nfqws2
	$(INSTALL_DIR) $(1)/usr/share/nfqws2
	$(CP) $(CURDIR)/src/root/usr/share/nfqws2/generate_conf.sh $(1)/usr/share/nfqws2/
endef

define Package/luci-app-nfqws2/conffiles
/etc/config/nfqws2
endef

define Package/luci-app-nfqws2/postinst
#!/bin/sh
[ -e /etc/init.d/nfqws2 ] || ln -sf /etc/init.d/nfqws2-keenetic /etc/init.d/nfqws2
exit 0
endef

$(eval $(call BuildPackage,luci-app-nfqws2))
