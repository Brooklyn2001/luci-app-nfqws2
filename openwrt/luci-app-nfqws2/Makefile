include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nfqws2
PKG_VERSION:=$(shell cat ../../VERSION 2>/dev/null || echo "1.0.0")
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-nfqws2
  TITLE:=Web interface for NFQWS2
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  DEPENDS:=+uhttpd +jsonfilter +nfqws2-keenetic +luci-base
  PKGARCH:=all
  URL:=https://github.com/nfqws2/nfqws2-openwrt
endef

define Package/luci-app-nfqws2/description
  LuCI integrated interface for NFQWS2 DPI bypass.
endef

define Build/Prepare
	$(Build/Prepare/Default)
endef

define Build/Compile
endef

define Package/luci-app-nfqws2/install
	$(INSTALL_DIR) $(1)/www/nfqws2
	$(CP) $(CURDIR)/src/www/nfqws2/* $(1)/www/nfqws2/
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) $(CURDIR)/src/www/cgi-bin/nfqws2.sh $(1)/www/cgi-bin/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/nfqws2
	$(CP) $(CURDIR)/src/www/luci-static/resources/view/nfqws2/* $(1)/www/luci-static/resources/view/nfqws2/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(CP) $(CURDIR)/src/root/usr/share/luci/menu.d/luci-app-nfqws2.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/etc/config
	$(CP) $(CURDIR)/src/root/etc/config/nfqws2 $(1)/etc/config/nfqws2
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
rm -rf /tmp/luci-modulecache
exit 0
endef

$(eval $(call BuildPackage,luci-app-nfqws2))
