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
	# No compilation needed, just copy files
endef

define Package/luci-app-nfqws2/install
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/nfqws2 $(1)/etc/init.d/nfqws2
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/* $(1)/usr/lib/lua/luci/model/cbi/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(CP) $(PKG_BUILD_DIR)/po/* $(1)/usr/lib/lua/luci/i18n/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(CP) $(PKG_BUILD_DIR)/root/usr/share/luci/menu.d/*.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/usr/share/ucode/luci/controller
	$(CP) $(PKG_BUILD_DIR)/ucode/controller/*.uc $(1)/usr/share/ucode/luci/controller/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(CP) $(PKG_BUILD_DIR)/root/usr/share/rpcd/acl.d/*.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/apk/triggers
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/share/apk/triggers/luci-app-nfqws2 $(1)/usr/share/apk/triggers/luci-app-nfqws2
endef

define Package/luci-app-nfqws2/conffiles
/etc/config/nfqws2
endef

define Package/luci-app-nfqws2/postinst
#!/bin/sh
[ -e /etc/init.d/nfqws2 ] || ln -sf /etc/init.d/nfqws2-keenetic /etc/init.d/nfqws2
[ -e /etc/config/nfqws2 ] || {
    cat <<'EOF' > /etc/config/nfqws2
config nfqws2 'general'
    option enabled '0'
    option port '443'
    option bind_addr '0.0.0.0'
EOF
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-nfqws2))
