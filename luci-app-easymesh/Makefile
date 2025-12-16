#
#-- TorGuard
#
#--Add +wpad-mesh-openssl or wpa package for build

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-easymesh
PKG_VERSION:=3.8.17
PKG_RELEASE:=$(AUTORELEASE)
PKG_MAINTAINER:=TorGuard <admin@torguard.net>

LUCI_TITLE:=LuCI Support for easymesh
LUCI_DEPENDS:= +kmod-cfg80211 +batctl-default +kmod-batman-adv +dawn +luci-compat +luci-lua-runtime +bash +libiwinfo-lua +luci-proto-batman-adv

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
