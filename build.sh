#!/bin/bash
#
# One build script to rule them all
#
# The challenge: Old versions of non komodo coins need old versions of BerkeleyDB and Boost
# Annoyance in previous method: We build bdb for every single coin.. they should all be able to build from the same dependency
#
# Most bitcoin based coins will follow the same build steps
#
# Usage: ./build <coinname>
# e.g.: ./build LTC
#
# @author webworker01
#
scriptpath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

log()
{
    local category=$1
    local message=$2
    local color=$3
    local mode=$4

    local datetime=$(date '+%Y-%m-%d %H:%M:%S')

    case $color in
        red)
            colorcode=31
            ;;
        green)
            colorcode=32
            ;;
        yellow)
            colorcode=33
            ;;
        blue)
            colorcode=34
            ;;
        *)
            colorcode=32
            ;;
    esac

    if [[ $mode != "echo" ]] && [[ ! -z $nntoolslogfile ]]; then
        echo "${datetime} [${category}] ${message}" >> $nntoolslogfile
    fi
    if [[ $mode != "file" ]]; then
        printf "\033[0;${colorcode}m${datetime} [${category}] ${message}\033[0m\n"
    fi
}

bdb_PATH="${HOME}/berkeleydb48"

gccversion=$(gcc --version | head -1 | awk '{print $4}' | cut -d"." -f1)

# Functions
berkeleydb48 () {
    if [[ ! -f "${bdb_PATH}/include/db_cxx.h" || ! -f "${bdb_PATH}/lib/libdb_cxx-4.8.a" ]]; then
        log "build" "installing BerkeleyDB48"
        sleep 100
        cd $HOME
        mkdir -p $bdb_PATH
        wget -N 'http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz'
        echo '12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef db-4.8.30.NC.tar.gz' | sha256sum -c
        tar -xzvf db-4.8.30.NC.tar.gz

        cat <<-EOL >atomic-builtin-test.cpp
            #include <stdint.h>
            #include "atomic.h"

            int main() {
            db_atomic_t *p; atomic_value_t oldval; atomic_value_t newval;
            __atomic_compare_exchange(p, oldval, newval);
            return 0;
            }
EOL
        if g++ atomic-builtin-test.cpp -I./db-4.8.30.NC/dbinc -DHAVE_ATOMIC_SUPPORT -DHAVE_ATOMIC_X86_GCC_ASSEMBLY -o atomic-builtin-test 2>/dev/null; then
            log "build" "No changes to bdb source are needed ..."
            rm atomic-builtin-test 2>/dev/null
        else
            log "build" "Updating atomic.h file ..."
            sed -i 's/__atomic_compare_exchange/__atomic_compare_exchange_db/g' db-4.8.30.NC/dbinc/atomic.h
        fi

        cd db-4.8.30.NC/build_unix/
        ../dist/configure -enable-cxx -disable-shared -with-pic -prefix=$bdb_PATH

        make install

        #clean up
        cd $HOME
        rm atomic-builtin-test.cpp
        rm db-4.8.30.NC.tar.gz
        rm -rf db-4.8.30.NC
    else
        log "build" "BerkeleyDB 4.8 detected in ${bdb_PATH}"
    fi
}

boost165 () {
    #check if boost <= 1.71 already installed
    cd $HOME/c
    if make boost; then
        boostversion=$(./boost | sed 's/_/./g')
        rm boost
    else
        log "build" "error building boost check" "red"
    fi

    if (( $(echo "${boostversion-999} > 1.71" | bc -l) )); then
        log "build" "installing Boost 1_65_1"
        sleep 100
        #remove apt installed versions
        sudo apt-get -y --purge remove libboost-all-dev libboost-doc libboost-dev libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
        sudo apt autoremove
        #remove source installed versions
        sudo rm -f /usr/lib/libboost_*
        sudo rm -f /usr/local/lib/libboost_*
        cd /usr/local/include && sudo rm -rf boost

        #build from source if not
        cd $HOME
        wget http://downloads.sourceforge.net/project/boost/boost/1.65.1/boost_1_65_1.tar.gz
        tar -zxvf boost_1_65_1.tar.gz
        cd boost_1_65_1
        # ./bootstrap.sh --prefix=/usr --with-libraries=atomic,date_time,exception,filesystem,iostreams,locale,program_options,regex,signals,system,test,thread,timer,log
        ./bootstrap.sh --prefix=/usr --with-libraries=chrono,filesystem,program_options,system,test,thread

        sudo ./b2 --with=all -j$(expr $(nproc) - 1) install

        #clean up
        cd $HOME
        rm boost_1_65_1.tar.gz
        rm -rf boost_1_65_1
    else
        log "build" "Valid Boost Version Installed: ${boostversion}"
    fi
}

buildBitcoinBased () {
    
    cd /home/sipeed/bitcoin-22.0/
    make clean
    ./autogen.sh

    if (( gccversion > 9 )) && [[ "${buildflags}" == "gcc9" ]]; then
        # install g++ 7 compiler for chips for now
        gccflags="CC=gcc-9 CXX=g++-9"
        log "build" "using g++9"
    fi

    ./configure LDFLAGS="-L${bdb_PATH}/lib/" CPPFLAGS="-I${bdb_PATH}/include/" ${gccflags-} --with-gui=no --disable-tests --disable-bench --without-miniupnpc --enable-experimental-asm --enable-static --disable-shared

    make
}

log "build" "${coinname} - bitcoin based build"

berkeleydb48
boost165
buildBitcoinBased
