project(libponyrt VERSION ${PONYC_VERSION} LANGUAGES C CXX)

set(_ll_src "${CMAKE_SOURCE_DIR}/src/libponyrt/lang/except_try_catch.ll")
set(_ll_obj "${CMAKE_BINARY_DIR}/except_try_catch.o")

add_library(libponyrt STATIC
    actor/actor.c
    actor/messageq.c
    asio/asio.c
    asio/epoll.c
    asio/event.c
    asio/iocp.c
    asio/kqueue.c
    ds/fun.c
    ds/hash.c
    ds/list.c
    ds/stack.c
    gc/actormap.c
    gc/cycle.c
    gc/delta.c
    gc/gc.c
    gc/objectmap.c
    gc/serialise.c
    gc/trace.c
    lang/directory.c
    lang/io.c
    lang/lsda.c
    lang/paths.c
    lang/posix_except.c
    lang/process.c
    lang/socket.c
    lang/ssl.c
    lang/stat.c
    lang/stdfd.c
    lang/time.c
    lang/win_except.c
    mem/alloc.c
    mem/heap.c
    mem/pagemap.c
    mem/pool.c
    options/options.c
    platform/ponyassert.c
    platform/threads.c
    sched/cpu.c
    sched/mpmcq.c
    sched/mutemap.c
    sched/scheduler.c
    sched/start.c
    ${_ll_obj}
)

add_custom_command(
    COMMAND "../../../libs/bin/llc" -relocation-model=pic -filetype=obj -o ${_ll_obj} ${_ll_src}
    WORKING_DIRECTORY ${libponyrt_BINARY_DIR}
    DEPENDS ${_ll_src}
    OUTPUT ${_ll_obj}
)

target_include_directories(libponyrt
    PRIVATE .
    PRIVATE ../common
)

if (MSVC)
    file(GLOB_RECURSE CFILES "${PROJECT_SOURCE_DIR}/*.c")
    set_source_files_properties(${CFILES} PROPERTIES LANGUAGE CXX)

    # copy libponyrt to the ponyc directory for use when linking pony programs
    add_custom_command(TARGET libponyrt POST_BUILD
        COMMAND $<$<CONFIG:Debug>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/debug/libponyrt.lib ${CMAKE_BINARY_DIR}/../debug/libponyrt.lib
        COMMAND $<$<CONFIG:Release>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/release/libponyrt.lib ${CMAKE_BINARY_DIR}/../release/libponyrt.lib
        COMMAND $<$<CONFIG:RelWithDebInfo>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/relwithdebinfo/libponyrt.lib ${CMAKE_BINARY_DIR}/../relwithdebinfo/libponyrt.lib
        COMMAND $<$<CONFIG:MinSizeRel>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/minsizerel/libponyrt.lib ${CMAKE_BINARY_DIR}/../minsizerel/libponyrt.lib
    )
else()
    target_include_directories(libponyrt
        PRIVATE /usr/local/include
    )

    if(${CMAKE_HOST_SYSTEM_NAME} MATCHES "Darwin")
        set(LIBPONYRT_ARCHIVE libponyrt.a)
    elseif(${CMAKE_HOST_SYSTEM_NAME} MATCHES "BSD")
        set(LIBPONYRT_ARCHIVE libponyrt.a)
    else()
        set(LIBPONYRT_ARCHIVE libponyrt-pic.a)
    endif()

    # copy libponyrt to the ponyc directory for use when linking pony programs
    add_custom_command(TARGET libponyrt POST_BUILD
        COMMAND $<$<CONFIG:Debug>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/libponyrt.a ${CMAKE_BINARY_DIR}/../debug/${LIBPONYRT_ARCHIVE}
        COMMAND $<$<CONFIG:Release>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/libponyrt.a ${CMAKE_BINARY_DIR}/../release/${LIBPONYRT_ARCHIVE}
        COMMAND $<$<CONFIG:RelWithDebInfo>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/libponyrt.a ${CMAKE_BINARY_DIR}/../relwithdebinfo/${LIBPONYRT_ARCHIVE}
        COMMAND $<$<CONFIG:MinSizeRel>:${CMAKE_COMMAND}> ARGS -E copy ${libponyrt_BINARY_DIR}/minsizerel/libponyrt.a ${CMAKE_BINARY_DIR}/../minsizerel/${LIBPONYRT_ARCHIVE}
    )
endif (MSVC)
