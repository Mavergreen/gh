cmake_minimum_required(VERSION 3.25)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../UPSTREAM_VERSION" GH_VERSION LIMIT_COUNT 1)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION")
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION" GH_VERSION LIMIT_COUNT 1)
endif()

project(GhUpdater LANGUAGES OBJC)
find_package(MavericksShipyard REQUIRED)
set(MAVERICKS_REQUIRE_APPLECLANG OFF)
include(Mavericks)
include(MavericksSparkle)
mavericks_add_updater_app(
  PRODUCT gh
  PRODUCT_NAME "Mavericks GitHub CLI"
  ALLOW_GENERIC
  ED_PUBKEY_FILE "${CMAKE_CURRENT_SOURCE_DIR}/ed25519_key.pub"
  VERSION "${GH_VERSION}"
  CONFIRM_TITLE "GitHub CLI for Mavericks updated"
  CONFIRM_BODY "gh was updated. New shells and agents get the new version.")
