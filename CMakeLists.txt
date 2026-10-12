cmake_minimum_required(VERSION 3.25)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/UPSTREAM_VERSION" GH_UPSTREAM LIMIT_COUNT 1)
set(GH_VERSION "${GH_UPSTREAM}")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" GH_VERSION LIMIT_COUNT 1)
endif()

project(GhForMavericks LANGUAGES C)

find_package(MavericksShipyard REQUIRED)
include(Mavericks)
include(MavericksMode)
mavericks_build_mode(MAVERICKS_MODE)
mavericks_require_expected_mode("${MAVERICKS_MODE}")
message(STATUS "GitHub CLI for Mavericks ${GH_VERSION}: build mode ${MAVERICKS_MODE}")

# The Go line (1.27.2-mavericks.1 -> 127) comes from the toolchain pin, so moving to the next line is
# the pin plus renovate.json, nothing here.
file(STRINGS "${CMAKE_SOURCE_DIR}/components/golang/version" _gopin LIMIT_COUNT 1)
if(NOT _gopin MATCHES "^([0-9]+)\\.([0-9]+)\\.")
  message(FATAL_ERROR "components/golang/version: cannot read a Go line from '${_gopin}'")
endif()
set(GH_GO_LINE "${CMAKE_MATCH_1}${CMAKE_MATCH_2}")
if(MAVERICKS_MODE STREQUAL "native")
  set(GH_GO "/usr/local/mavergreen/go${GH_GO_LINE}/bin/go")
  set(_gopkg "native")
else()
  set(GH_GO "/usr/local/mavergreen/go${GH_GO_LINE}-cross/bin/go")
  set(_gopkg "cross")
endif()
if(NOT EXISTS "${GH_GO}")
  message(FATAL_ERROR "A ${MAVERICKS_MODE} build needs ${GH_GO}: install the ${_gopkg} .pkg from "
    "https://github.com/Mavergreen/golang-${GH_GO_LINE}/releases "
    "(components/golang/version pins ${_gopin}).")
endif()

enable_testing()

set(GH_GOBIN "${CMAKE_BINARY_DIR}/gobin")
add_custom_command(
  OUTPUT "${GH_GOBIN}/gh" "${GH_GOBIN}/LICENSE"
  COMMAND sh "${CMAKE_SOURCE_DIR}/build/build-gh.sh" "${GH_GO}" "${GH_GOBIN}" "${GH_UPSTREAM}"
  DEPENDS "${CMAKE_SOURCE_DIR}/build/build-gh.sh"
          "${CMAKE_SOURCE_DIR}/UPSTREAM_VERSION"
          "${CMAKE_SOURCE_DIR}/components/golang/version"
  COMMENT "building gh ${GH_UPSTREAM} for 10.9"
  VERBATIM)
add_custom_target(gh_binary ALL DEPENDS "${GH_GOBIN}/gh" "${GH_GOBIN}/LICENSE")

# spec: INGREDIENTS.md "Decisions" -- labelColor is a Go struct field, not an ObjC selector
add_test(NAME compat_guard_gh
  COMMAND ${CMAKE_COMMAND} -E env MAVERICKS_REQUIRE_DEFINED_SYMBOLS=_clock_gettime
    MAVERICKS_ALLOW_SELECTORS=labelColor
    sh "${MavericksShipyard_SCRIPTS}/assert_binary_compatible.sh" "${GH_GOBIN}/gh")

# A cross build's x86_64 gh runs on a 10.9 guest instead (release.yml's on-mavericks job).
if(MAVERICKS_MODE STREQUAL "native")
  add_test(NAME gh_runs COMMAND sh "${CMAKE_SOURCE_DIR}/tests/gh-runs-test.sh" "${GH_GOBIN}/gh")
  set_tests_properties(gh_runs PROPERTIES SKIP_RETURN_CODE 77)
endif()
