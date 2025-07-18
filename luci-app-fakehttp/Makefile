# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2025 Yuxi Yang <i@bgme.me>

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for fakehttp
LUCI_DEPENDS:=+luci-base +fakehttp
LUCI_PKGARCH:=all

PKG_MAINTAINER:=Yuxi Yang <i@bgme.me>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
