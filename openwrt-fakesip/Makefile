# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2025 Yuxi Yang <i@bgme.me>

include $(TOPDIR)/rules.mk

PKG_NAME:=fakesip
PKG_UPSTREAM_NAME:=FakeSIP
PKG_UPSTREAM_VERSION:=0.9.1
PKG_UPSTREAM_GITHASH:=
PKG_VERSION:=$(PKG_UPSTREAM_VERSION)$(if $(PKG_UPSTREAM_GITHASH),~$(call version_abbrev,$(PKG_UPSTREAM_GITHASH)))
PKG_RELEASE:=3

PKG_SOURCE_SUBDIR:=$(PKG_UPSTREAM_NAME)-$(PKG_UPSTREAM_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

ifeq ($(PKG_UPSTREAM_GITHASH),)
PKG_SOURCE_URL:=https://codeload.github.com/MikeWang000000/FakeSIP/tar.gz/refs/tags/$(PKG_UPSTREAM_VERSION)?
PKG_HASH:=1216d9649fb69e5a1deaf48c3d48c26f9418bd18ffe15f44b0cf33039dbb3478

PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.gz
else
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/MikeWang000000/FakeSIP.git
PKG_SOURCE_VERSION:=$(PKG_UPSTREAM_GITHASH)
PKG_MIRROR_HASH:=skip

PKG_SOURCE:=$(PKG_SOURCE_SUBDIR)-$(PKG_SOURCE_VERSION).tar.gz
endif

PKG_MAINTAINER:=Yuxi Yang <i@bgme.me>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Obfuscate all your UDP connections into SIP protocol.
	URL:=https://github.com/MikeWang000000/FakeSIP
	DEPENDS:=+libmnl +libnfnetlink +libnetfilter-queue +kmod-nft-queue +nftables
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/fakesip
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/fakesip $(1)/usr/sbin/fakesip

	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_BIN) $(CURDIR)/files/fakesip.init $(1)/etc/init.d/fakesip

	$(INSTALL_DIR) $(1)/etc/config/
	$(INSTALL_CONF) $(CURDIR)/files/fakesip.config $(1)/etc/config/fakesip

	$(INSTALL_DIR) $(1)/etc/fakesip/
	$(INSTALL_CONF) $(CURDIR)/files/fakesip.payload $(1)/etc/fakesip/example_payload
endef

$(eval $(call BuildPackage,$(PKG_NAME)))