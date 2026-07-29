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
  DEPENDS:=+luci-base
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
endef

define Package/luci-app-nfqws2/conffiles
/etc/config/nfqws2
endef

$(eval $(call BuildPackage,luci-app-nfqws2))
