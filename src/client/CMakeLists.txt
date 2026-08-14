add_definitions(-DCLIENT)

# Protobuf: generate appearances.pb.{h,cc} and staticdata.pb.{h,cc} from
# src/client/proto/*.proto into ${CMAKE_BINARY_DIR}/generated/proto/ (which the
# root CMakeLists.txt adds to include_directories), so consumers just
# #include "appearances.pb.h".
#
# We drive protoc directly instead of going through protobuf_generate_cpp():
# that macro's signature differs between CMake's bundled FindProtobuf and the
# protobuf-config.cmake that vcpkg ships (only the latter understands
# PROTOC_OUT_DIR), so calling it portably is not possible. Two .proto files with
# no imports do not need the macro's dependency scanning anyway.
set(PROTO_GEN_DIR ${CMAKE_BINARY_DIR}/generated/proto)
file(MAKE_DIRECTORY ${PROTO_GEN_DIR})

if(TARGET protobuf::protoc)
    set(PROTOC_EXECUTABLE protobuf::protoc)
elseif(Protobuf_PROTOC_EXECUTABLE)
    set(PROTOC_EXECUTABLE ${Protobuf_PROTOC_EXECUTABLE})
else()
    message(FATAL_ERROR "protoc not found - is the vcpkg toolchain file being used?")
endif()

set(PROTO_SRCS "")
set(PROTO_HDRS "")
foreach(proto_name appearances staticdata)
    set(proto_file ${CMAKE_CURRENT_LIST_DIR}/proto/${proto_name}.proto)
    add_custom_command(
        OUTPUT ${PROTO_GEN_DIR}/${proto_name}.pb.cc ${PROTO_GEN_DIR}/${proto_name}.pb.h
        COMMAND ${PROTOC_EXECUTABLE}
                --proto_path=${CMAKE_CURRENT_LIST_DIR}/proto
                --cpp_out=${PROTO_GEN_DIR}
                ${proto_file}
        DEPENDS ${proto_file} ${PROTOC_EXECUTABLE}
        COMMENT "Generating ${proto_name}.pb.cc"
        VERBATIM)
    list(APPEND PROTO_SRCS ${PROTO_GEN_DIR}/${proto_name}.pb.cc)
    list(APPEND PROTO_HDRS ${PROTO_GEN_DIR}/${proto_name}.pb.h)
endforeach()

# The generated code trips MSVC's C4996/C5054-style warnings-as-noise; it is not
# ours to fix, so keep it out of the warning stream.
if(MSVC)
    set_source_files_properties(${PROTO_SRCS} PROPERTIES COMPILE_FLAGS "/w")
endif()

set(client_SOURCES ${client_SOURCES}
    ${PROTO_SRCS}

    # client
    ${CMAKE_CURRENT_LIST_DIR}/const.h
    ${CMAKE_CURRENT_LIST_DIR}/global.h
    ${CMAKE_CURRENT_LIST_DIR}/luafunctions_client.cpp
    ${CMAKE_CURRENT_LIST_DIR}/client.cpp
    ${CMAKE_CURRENT_LIST_DIR}/client.h

    # core
    ${CMAKE_CURRENT_LIST_DIR}/animatedtext.cpp
    ${CMAKE_CURRENT_LIST_DIR}/animatedtext.h
    ${CMAKE_CURRENT_LIST_DIR}/animator.h
    ${CMAKE_CURRENT_LIST_DIR}/animator.cpp
    ${CMAKE_CURRENT_LIST_DIR}/container.cpp
    ${CMAKE_CURRENT_LIST_DIR}/container.h
    ${CMAKE_CURRENT_LIST_DIR}/creature.cpp
    ${CMAKE_CURRENT_LIST_DIR}/creature.h
    ${CMAKE_CURRENT_LIST_DIR}/declarations.h
    ${CMAKE_CURRENT_LIST_DIR}/effect.cpp
    ${CMAKE_CURRENT_LIST_DIR}/effect.h
    ${CMAKE_CURRENT_LIST_DIR}/game.cpp
    ${CMAKE_CURRENT_LIST_DIR}/game.h
    ${CMAKE_CURRENT_LIST_DIR}/item.cpp
    ${CMAKE_CURRENT_LIST_DIR}/item.h
    ${CMAKE_CURRENT_LIST_DIR}/localplayer.cpp
    ${CMAKE_CURRENT_LIST_DIR}/localplayer.h
    ${CMAKE_CURRENT_LIST_DIR}/map.cpp
    ${CMAKE_CURRENT_LIST_DIR}/map.h
    ${CMAKE_CURRENT_LIST_DIR}/mapio.cpp
    ${CMAKE_CURRENT_LIST_DIR}/mapview.cpp
    ${CMAKE_CURRENT_LIST_DIR}/mapview.h
    ${CMAKE_CURRENT_LIST_DIR}/minimap.cpp
    ${CMAKE_CURRENT_LIST_DIR}/minimap.h
    ${CMAKE_CURRENT_LIST_DIR}/lightview.cpp
    ${CMAKE_CURRENT_LIST_DIR}/lightview.h
    ${CMAKE_CURRENT_LIST_DIR}/missile.cpp
    ${CMAKE_CURRENT_LIST_DIR}/missile.h
    ${CMAKE_CURRENT_LIST_DIR}/outfit.cpp
    ${CMAKE_CURRENT_LIST_DIR}/outfit.h
    ${CMAKE_CURRENT_LIST_DIR}/player.cpp
    ${CMAKE_CURRENT_LIST_DIR}/player.h
    ${CMAKE_CURRENT_LIST_DIR}/spritemanager.cpp
    ${CMAKE_CURRENT_LIST_DIR}/spritemanager.h
    ${CMAKE_CURRENT_LIST_DIR}/staticdata.h
    ${CMAKE_CURRENT_LIST_DIR}/statictext.cpp
    ${CMAKE_CURRENT_LIST_DIR}/statictext.h
    ${CMAKE_CURRENT_LIST_DIR}/thing.cpp
    ${CMAKE_CURRENT_LIST_DIR}/thing.h
    ${CMAKE_CURRENT_LIST_DIR}/thingtypemanager.cpp
    ${CMAKE_CURRENT_LIST_DIR}/thingtypemanager.h
    ${CMAKE_CURRENT_LIST_DIR}/thingtype.cpp
    ${CMAKE_CURRENT_LIST_DIR}/thingtype.h
    ${CMAKE_CURRENT_LIST_DIR}/appearancesloader.cpp
    ${CMAKE_CURRENT_LIST_DIR}/appearancesloader.h
    ${CMAKE_CURRENT_LIST_DIR}/spritesheetloader.cpp
    ${CMAKE_CURRENT_LIST_DIR}/spritesheetloader.h
    ${CMAKE_CURRENT_LIST_DIR}/itemtype.cpp
    ${CMAKE_CURRENT_LIST_DIR}/itemtype.h
    ${CMAKE_CURRENT_LIST_DIR}/tile.cpp
    ${CMAKE_CURRENT_LIST_DIR}/tile.h
    ${CMAKE_CURRENT_LIST_DIR}/healthbars.cpp
    ${CMAKE_CURRENT_LIST_DIR}/healthbars.h
    ${CMAKE_CURRENT_LIST_DIR}/houses.cpp
    ${CMAKE_CURRENT_LIST_DIR}/houses.h
    ${CMAKE_CURRENT_LIST_DIR}/towns.cpp
    ${CMAKE_CURRENT_LIST_DIR}/towns.h
    ${CMAKE_CURRENT_LIST_DIR}/creatures.cpp
    ${CMAKE_CURRENT_LIST_DIR}/creatures.h

    # lua
    ${CMAKE_CURRENT_LIST_DIR}/luavaluecasts_client.cpp
    ${CMAKE_CURRENT_LIST_DIR}/luavaluecasts_client.h

    # net
    ${CMAKE_CURRENT_LIST_DIR}/protocolcodes.cpp
    ${CMAKE_CURRENT_LIST_DIR}/protocolcodes.h
    ${CMAKE_CURRENT_LIST_DIR}/protocolgame.cpp
    ${CMAKE_CURRENT_LIST_DIR}/protocolgame.h
    ${CMAKE_CURRENT_LIST_DIR}/protocolgameparse.cpp
    ${CMAKE_CURRENT_LIST_DIR}/protocolgamesend.cpp

    # ui
    ${CMAKE_CURRENT_LIST_DIR}/uicreature.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uicreature.h
    ${CMAKE_CURRENT_LIST_DIR}/uiitem.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uiitem.h
    ${CMAKE_CURRENT_LIST_DIR}/uigraph.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uigraph.h
    ${CMAKE_CURRENT_LIST_DIR}/uigrid.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uigrid.h
    ${CMAKE_CURRENT_LIST_DIR}/uimap.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uimap.h
    ${CMAKE_CURRENT_LIST_DIR}/uiminimap.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uiminimap.h
    ${CMAKE_CURRENT_LIST_DIR}/uiprogressrect.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uiprogressrect.h
    ${CMAKE_CURRENT_LIST_DIR}/uimapanchorlayout.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uimapanchorlayout.h
    ${CMAKE_CURRENT_LIST_DIR}/uisprite.cpp
    ${CMAKE_CURRENT_LIST_DIR}/uisprite.h

    # util
    ${CMAKE_CURRENT_LIST_DIR}/position.h
)

# Wire Protobuf headers + generated-source dir + lib into the (single) executable target.
# This file is included from the root CMakeLists.txt _before_ add_executable, so we can only
# extend the *_INCLUDE_DIRS / *_LIBRARIES lists that the root then consumes.
include_directories(${Protobuf_INCLUDE_DIRS} ${PROTO_GEN_DIR})

# Prefer the imported target: since protobuf 22 the library pulls in a dozen
# abseil archives, and only the target carries those transitively.
if(TARGET protobuf::libprotobuf)
    set(framework_LIBRARIES ${framework_LIBRARIES} protobuf::libprotobuf)
else()
    set(framework_LIBRARIES ${framework_LIBRARIES} ${Protobuf_LIBRARIES})
endif()
