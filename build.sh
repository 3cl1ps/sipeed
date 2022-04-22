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

bdb_PATH="${HOME}/berkeleydb48"

gccversion=$(gcc --version | head -1 | awk '{print $4}' | cut -d"." -f1)

# Functions
berkeleydb48 () {
    if [[ ! -f "${bdb_PATH}/include/db_cxx.h" || ! -f "${bdb_PATH}/lib/libdb_cxx-4.8.a" ]]; then
        echo "build" "installing BerkeleyDB48"
        sleep 100
        cd $HOME
        mkdir -p $bdb_PATH
        wget -N 'http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz'
        echo '12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef db-4.8.30.NC.tar.gz' | sha256sum -c
        tar -xzvf db-4.8.30.NC.tar.gz
         cd db-4.8.30.NC/build_unix/
        ../dist/configure -enable-cxx -disable-shared -with-pic -prefix=$bdb_PATH

        make install

        #clean up
        cd $HOME
        rm db-4.8.30.NC.tar.gz
        rm -rf db-4.8.30.NC
    else
        echo "build" "BerkeleyDB 4.8 detected in ${bdb_PATH}"
    fi
}

boost165 () {
    #check if boost <= 1.71 already installed
    cd $HOME/c
    if make boost; then
        boostversion=$(./boost | sed 's/_/./g')
        rm boost
    else
        echo "build" "error building boost check" "red"
    fi

    if (( $(echo "${boostversion-999} > 1.71" | bc -l) )); then
        echo "build" "installing Boost 1_65_1"
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
        echo "build" "Valid Boost Version Installed: ${boostversion}"
    fi
}

buildBitcoinBased () {
    
    cd /home/sipeed/bitcoin-22.0/
    make clean
    ./autogen.sh

    if (( gccversion > 9 )) && [[ "${buildflags}" == "gcc9" ]]; then
        # install g++ 7 compiler for chips for now
        gccflags="CC=gcc-9 CXX=g++-9"
        echo "build" "using g++9"
    fi

    ./configure LDFLAGS="-L${bdb_PATH}/lib/" CPPFLAGS="-I${bdb_PATH}/include/" ${gccflags-} --with-gui=no --disable-tests --disable-bench --without-miniupnpc --enable-experimental-asm --enable-static --disable-shared
    make
}

echo "build" "${coinname} - bitcoin based build"

berkeleydb48
boost165
buildBitcoinBased
