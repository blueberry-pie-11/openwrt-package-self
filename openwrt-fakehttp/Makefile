# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2025 Yuxi Yang <i@bgme.me>

include $(TOPDIR)/rules.mk

PKG_NAME:=fakehttp
PKG_UPSTREAM_NAME:=FakeHTTP
PKG_UPSTREAM_VERSION:=0.9.18
PKG_UPSTREAM_GITHASH:=
PKG_VERSION:=$(PKG_UPSTREAM_VERSION)$(if $(PKG_UPSTREAM_GITHASH),~$(call version_abbrev,$(PKG_UPSTREAM_GITHASH)))
PKG_RELEASE:=3

PKG_SOURCE_SUBDIR:=$(PKG_UPSTREAM_NAME)-$(PKG_UPSTREAM_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

ifeq ($(PKG_UPSTREAM_GITHASH),)
PKG_SOURCE_URL:=https://codeload.github.com/MikeWang000000/FakeHTTP/tar.gz/refs/tags/$(PKG_UPSTREAM_VERSION)?
PKG_HASH:=c95c4d46e122390b0dcfd8509c708a6fc6817fb3e325cb966bf81a62bae973be

PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.gz
else
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/MikeWang000000/FakeHTTP.git
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
	TITLE:=Obfuscate all your TCP connections into HTTP protocol.
	URL:=https://github.com/MikeWang000000/FakeHTTP
	DEPENDS:=+libmnl +libnfnetlink +libnetfilter-queue +kmod-nft-queue +nftables
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/fakehttp
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/fakehttp $(1)/usr/sbin/fakehttp

	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_BIN) $(CURDIR)/files/fakehttp.init $(1)/etc/init.d/fakehttp

	$(INSTALL_DIR) $(1)/etc/config/
	$(INSTALL_CONF) $(CURDIR)/files/fakehttp.config $(1)/etc/config/fakehttp

	$(INSTALL_DIR) $(1)/etc/fakehttp/
	$(INSTALL_CONF) $(CURDIR)/files/fakehtttp.payload $(1)/etc/fakehttp/example_payload
endef

$(eval $(call BuildPackage,$(PKG_NAME)))