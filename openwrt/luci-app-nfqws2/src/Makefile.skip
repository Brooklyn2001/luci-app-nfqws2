include $(TOPDIR)/rules.mk

LUCI_TITLE:=NFQWS2 DPI Bypass Web Interface
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+nfqws2-keenetic +curl
LUCI_EXTRA_DEPENDS:=luci-base
LUCI_PACKAGER:=nfqws2

define Package/luci-app-nfqws2/conffiles
/etc/config/nfqws2
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - already called by luci.mk
