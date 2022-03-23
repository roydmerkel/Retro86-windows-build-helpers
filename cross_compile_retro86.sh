#!/usr/bin/env bash
# ffmpeg windows cross compile helper/download script, see github repo README
# Copyright (C) 2012 Roger Pack, the script is under the GPLv3, but output FFmpeg's executables aren't
# set -x

set_box_memory_size_bytes() {
  if [[ $OSTYPE == darwin* ]]; then
    box_memory_size_bytes=20000000000 # 20G fake it out for now :|
  else
    local ram_kilobytes=`grep MemTotal /proc/meminfo | awk '{print $2}'`
    local swap_kilobytes=`grep SwapTotal /proc/meminfo | awk '{print $2}'`
    box_memory_size_bytes=$[ram_kilobytes * 1024 + swap_kilobytes * 1024]
  fi
}

# Rather than keeping the versioning logic in the script we can pull it into it's own function
# So it can potentially be used if we needed other version comparisons done later.
# Also, using the logic built into sort seems more robust than a roll-your-own for comparing versions.
ver_comp() {
  [ "${1}" = "${2}" ] || [ "$(printf '%s\n%s' "${1}" "${2}" | sort --version-sort | head -n 1)" == "${1}" ]
}

check_missing_packages () {
  # We will need this later if we don't want to just constantly be grepping the /etc/os-release file
  if [ -z "${VENDOR}" ] && grep -E '(centos|rhel)' /etc/os-release &> /dev/null; then
    # In RHEL this should always be set anyway. But not so sure about CentOS
    VENDOR="redhat"
  fi
  # zeranoe's build scripts use wget, though we don't here...
  # other things we might need: cmake libgmp-dev libmpfr-dev libmpc-dev libboost-all-dev texinfo
  local check_packages=('curl' 'pkg-config' 'make' 'git' 'svn' 'gcc' 'autoconf' 'automake' 'yasm' 'cvs' 'flex' 'bison' 'makeinfo' 'g++' 'ed' 'hg' 'pax' 'unzip' 'patch' 'wget' 'xz' 'nasm' 'gperf' 'autogen' 'bzip2' 'cargo' 'wine' 'node' 'npm')  
  # autoconf-archive is just for leptonica FWIW
  # I'm not actually sure if VENDOR being set to centos is a thing or not. On all the centos boxes I can test on it's not been set at all.
  # that being said, if it where set I would imagine it would be set to centos... And this contition will satisfy the "Is not initially set"
  # case because the above code will assign "redhat" all the time.
  if [ -z "${VENDOR}" ] || [ "${VENDOR}" != "redhat" ] && [ "${VENDOR}" != "centos" ]; then
    check_packages+=('cmake')
  fi
  # libtool check is wonky...
  if [[ $OSTYPE == darwin* ]]; then
    check_packages+=('glibtoolize') # homebrew special :|
  else
    check_packages+=('libtoolize') # the rest of the world
  fi
  # Use hash to check if the packages exist or not. Type is a bash builtin which I'm told behaves differently between different versions of bash.
  for package in "${check_packages[@]}"; do
    hash "$package" &> /dev/null || missing_packages=("$package" "${missing_packages[@]}")
  done
  if [ "${VENDOR}" = "redhat" ] || [ "${VENDOR}" = "centos" ]; then
    if [ -n "$(hash cmake 2>&1)" ] && [ -n "$(hash cmake3 2>&1)" ]; then missing_packages=('cmake' "${missing_packages[@]}"); fi
  fi
  check_packages+=('wine-binfmt') # the rest of the world
  ls /usr/share/binfmts/wine 2>/dev/null 1>/dev/null || missing_packages=("wine-binfmt" "${missing_packages[@]}")
  if [[ -n "${missing_packages[@]}" ]]; then
    clear
    echo "Could not find the following execs (svn is actually package subversion, makeinfo is actually package texinfo, hg is actually package mercurial if you're missing them): ${missing_packages[*]}"
    echo 'Install the missing packages before running this script.'
    echo "for ubuntu: $ sudo apt-get install subversion curl texinfo g++ bison flex cvs yasm automake libtool autoconf gcc cmake git make pkg-config zlib1g-dev mercurial unzip pax nasm gperf autogen bzip2 cargo autoconf-archive -y"
    echo "for gentoo (a non ubuntu distro): same as above, but no g++, no gcc, git is dev-vcs/git, zlib1g-dev is zlib, pkg-config is dev-util/pkgconfig, add ed..."
    echo "for OS X (homebrew): brew install wget cvs hg yasm autogen automake autoconf cmake hg libtool xz pkg-config nasm bzip2 cargo autoconf-archive"
    echo "for debian: same as ubuntu, but also add libtool-bin and ed"
    echo "for RHEL/CentOS: First ensure you have epel repos available, then run $ sudo yum install subversion texinfo mercurial libtool autogen gperf nasm patch unzip pax ed gcc-c++ bison flex yasm automake autoconf gcc zlib-devel cvs bzip2 cargo cmake3 -y"
    echo "for fedora: if your distribution comes with a modern version of cmake then use the same as RHEL/CentOS but replace cmake3 with cmake."
    exit 1
  fi
  binfmts_wine=
  update-binfmts --display wine 2>/dev/null 1>/dev/null || binfmts_wine=1
  echo "$binfmts_wine"
  if [ "$binfmts_wine" ]; then
	  echo "Wine not defined as default binfmt for windows executables, please run: sudo update-binfmts --import /usr/share/binfmts/wine"
	  exit 1
  fi

  export REQUIRED_CMAKE_VERSION="3.0.0"
  for cmake_binary in 'cmake' 'cmake3'; do
    # We need to check both binaries the same way because the check for installed packages will work if *only* cmake3 is installed or
    # if *only* cmake is installed.
    # On top of that we ideally would handle the case where someone may have patched their version of cmake themselves, locally, but if
    # the version of cmake required move up to, say, 3.1.0 and the cmake3 package still only pulls in 3.0.0 flat, then the user having manually
    # installed cmake at a higher version wouldn't be detected.
    if hash "${cmake_binary}"  &> /dev/null; then
      cmake_version="$( "${cmake_binary}" --version | sed -e "s#${cmake_binary}##g" | head -n 1 | tr -cd '[0-9.\n]' )"
      if ver_comp "${REQUIRED_CMAKE_VERSION}" "${cmake_version}"; then
        export cmake_command="${cmake_binary}"
        break
      else
        echo "your ${cmake_binary} version is too old ${cmake_version} wanted ${REQUIRED_CMAKE_VERSION}"
      fi 
    fi
  done

  # If cmake_command never got assigned then there where no versions found which where sufficient.
  if [ -z "${cmake_command}" ]; then
    echo "there where no appropriate versions of cmake found on your machine."
    exit 1
  else
    # If cmake_command is set then either one of the cmake's is adequate.
    echo "cmake binary for this build will be ${cmake_command}"
  fi

  if [[ ! -f /usr/include/zlib.h ]]; then
    echo "warning: you may need to install zlib development headers first if you want to build mp4-box [on ubuntu: $ apt-get install zlib1g-dev] [on redhat/fedora distros: $ yum install zlib-devel]" # XXX do like configure does and attempt to compile and include zlib.h instead?
    sleep 1
  fi

  # doing the cut thing with an assigned variable dies on the version of yasm I have installed (which I'm pretty sure is the RHEL default)
  # because of all the trailing lines of stuff
  export REQUIRED_YASM_VERSION="1.2.0"
  yasm_binary=yasm
  yasm_version="$( "${yasm_binary}" --version |sed -e "s#${yasm_binary}##g" | head -n 1 | tr -dc '[0-9.\n]' )"
  if ! ver_comp "${REQUIRED_YASM_VERSION}" "${yasm_version}"; then
    echo "your yasm version is too old $yasm_version wanted ${REQUIRED_YASM_VERSION}"
    exit 1
  fi
}

check_missing_node_packages () {
  local check_node_packages=('apple-data-compression@v0.4.1')  
  # Use hash to check if the packages exist or not. Type is a bash builtin which I'm told behaves differently between different versions of bash.
  for package in "${check_node_packages[@]}"; do
    npm list --depth 1 --global "$package" > /dev/null 2>&1 || missing_node_packages=("$package" "${missing_node_packages[@]}")
  done
  if [[ -n "${missing_node_packages[@]}" ]]; then
    clear
    echo "Could not find the following node packages installed globally: ${missing_node_packages[*]}"
    echo 'Install the missing packages before running this script.'
    echo "$ sudo npm install -g ${check_node_packages[@]}"
    exit 1
  fi
}


intro() {
  echo `date`
  cat <<EOL
     ##################### Welcome ######################
  Welcome to the Retro86 cross-compile builder-helper script.
  Downloads and builds will be installed to directories within $cur_dir
  If this is not ok, then exit now, and cd to the directory where you'd
  like them installed, then run this script again from there.
  NB that once you build your compilers, you can no longer rename/move
  the sandbox directory, since it will have some hard coded paths in there.
  You can, of course, rebuild ffmpeg from within it, etc.
EOL
  if [[ $sandbox_ok != 'y' && ! -d sandbox ]]; then
    echo
    echo "Building in $PWD/sandbox, will use ~ 4GB space!"
    echo
  fi
  mkdir -p "$cur_dir"
  cd "$cur_dir"
}

pick_compiler_flavors() {
  while [[ "$compiler_flavors" != [1-4] ]]; do
    if [[ -n "${unknown_opts[@]}" ]]; then
      echo -n 'Unknown option(s)'
      for unknown_opt in "${unknown_opts[@]}"; do
        echo -n " '$unknown_opt'"
      done
      echo ', ignored.'; echo
    fi
    cat <<'EOF'
What version of MinGW-w64 would you like to build or update?
  1. Both Win32 and Win64
  2. Win32 (32-bit only)
  3. Win64 (64-bit only)
  4. Exit
EOF
    echo -n 'Input your choice [1-4]: '
    read compiler_flavors
  done
  case "$compiler_flavors" in
  1 ) compiler_flavors=multi ;;
  2 ) compiler_flavors=win32 ;;
  3 ) compiler_flavors=win64 ;;
  4 ) echo "exiting"; exit 0 ;;
  * ) clear;  echo 'Your choice was not valid, please try again.'; echo ;;
  esac
}

# made into a method so I don't/don't have to download this script every time if only doing just 32 or just6 64 bit builds...
download_gcc_build_script() {
    local zeranoe_script_name=$1
    rm -f $zeranoe_script_name || exit 1
    curl -4 file://$patch_dir/$zeranoe_script_name -O --fail || exit 1
    chmod u+x $zeranoe_script_name
}

install_cross_compiler() {
  local win32_gcc="cross_compilers/mingw-w64-i686/bin/i686-w64-mingw32-gcc"
  local win64_gcc="cross_compilers/mingw-w64-x86_64/bin/x86_64-w64-mingw32-gcc"
  if [[ -f $win32_gcc && -f $win64_gcc ]]; then
   echo "MinGW-w64 compilers both already installed, not re-installing..."
   if [[ -z $compiler_flavors ]]; then
     echo "selecting multi build (both win32 and win64)...since both cross compilers are present assuming you want both..."
     compiler_flavors=multi
   fi
   return # early exit just assume they want both, don't even prompt :)
  fi

  if [[ -z $compiler_flavors ]]; then
    pick_compiler_flavors
  fi

  mkdir -p cross_compilers
  cd cross_compilers

    unset CFLAGS # don't want these "windows target" settings used the compiler itself since it creates executables to run on the local box (we have a parameter allowing them to set them for the script "all builds" basically)
    # pthreads version to avoid having to use cvs for it
    echo "Starting to download and build cross compile version of gcc [requires working internet access] with thread count $gcc_cpu_count..."
    echo ""

    # --disable-shared allows c++ to be distributed at all...which seemed necessary for some random dependency which happens to use/require c++...
    local zeranoe_script_name=mingw-w64-build-r22.local
    local zeranoe_script_options="--gcc-ver=8.3.0 --default-configure --cpu-count=$gcc_cpu_count --pthreads-w32-ver=2-9-1 --disable-shared --clean-build --verbose --allow-overwrite" # allow-overwrite to avoid some crufty prompts if I do rebuilds [or maybe should just nuke everything...]
    if [[ ($compiler_flavors == "win32" || $compiler_flavors == "multi") && ! -f ../$win32_gcc ]]; then
      echo "Building win32 cross compiler..."
      download_gcc_build_script $zeranoe_script_name
      if [[ `uname` =~ "5.1" ]]; then # Avoid using secure API functions for compatibility with msvcrt.dll on Windows XP.
        sed -i "s/ --enable-secure-api//" $zeranoe_script_name
      fi
      nice ./$zeranoe_script_name $zeranoe_script_options --build-type=win32 || exit 1
      if [[ ! -f ../$win32_gcc ]]; then
        echo "Failure building 32 bit gcc? Recommend nuke sandbox (rm -rf sandbox) and start over..."
        exit 1
      fi
    fi
    if [[ ($compiler_flavors == "win64" || $compiler_flavors == "multi") && ! -f ../$win64_gcc ]]; then
      echo "Building win64 x86_64 cross compiler..."
      download_gcc_build_script $zeranoe_script_name
      nice ./$zeranoe_script_name $zeranoe_script_options --build-type=win64 || exit 1
      if [[ ! -f ../$win64_gcc ]]; then
        echo "Failure building 64 bit gcc? Recommend nuke sandbox (rm -rf sandbox) and start over..."
        exit 1
      fi
    fi

    # rm -f build.log # left over stuff... # sometimes useful...
    reset_cflags
  cd ..
  echo "Done building (or already built) MinGW-w64 cross-compiler(s) successfully..."
  echo `date` # so they can see how long it took :)
}

# helper methods for downloading and building projects that can take generic input

do_svn_checkout() {
  repo_url="$1"
  to_dir="$2"
  desired_revision="$3"
  if [ ! -d $to_dir ]; then
    echo "svn checking out to $to_dir"
    if [[ -z "$desired_revision" ]]; then
      svn checkout $repo_url $to_dir.tmp  --non-interactive --trust-server-cert || exit 1
    else
      svn checkout -r $desired_revision $repo_url $to_dir.tmp || exit 1
    fi
    mv $to_dir.tmp $to_dir
  else
    cd $to_dir
    echo "not svn Updating $to_dir since usually svn repo's aren't updated frequently enough..."
    # XXX accomodate for desired revision here if I ever uncomment the next line...
    # svn up
    cd ..
  fi
}

do_git_checkout() {
  local repo_url="$1"
  local to_dir="$2"
  if [[ -z $to_dir ]]; then
    to_dir=$(basename $repo_url | sed s/\.git/_git/) # http://y/abc.git -> abc_git
  fi
  local to_dir_done_name="$to_dir.done"
  echo "to_dir_done_name: $to_dir_done_name"
  if [[ ! -e $to_dir_done_name ]]; then
    local desired_branch="$3"
    if [ ! -d $to_dir ]; then
      echo "Downloading (via git clone) $to_dir from $repo_url"
      rm -rf $to_dir.tmp # just in case it was interrupted previously...
      git clone $repo_url $to_dir.tmp || exit 1
      # prevent partial checkouts by renaming it only after success
      mv $to_dir.tmp $to_dir
      echo "done git cloning to $to_dir"
      cd $to_dir
    else
      cd $to_dir
      if [[ $git_get_latest = "y" ]]; then
        git fetch # need this no matter what
      else
        echo "not doing git get latest pull for latest code $to_dir"
      fi
    fi

    old_git_version=`git rev-parse HEAD`

    if [[ -z $desired_branch ]]; then
      echo "doing git checkout master"
      git checkout -f master || exit 1 # in case they were on some other branch before [ex: going between ffmpeg release tags]. # -f: checkout even if the working tree differs from HEAD.
      if [[ $git_get_latest = "y" ]]; then
        echo "Updating to latest $to_dir git version [origin/master]..."
        git merge origin/master || exit 1
      fi
    else
      echo "doing git checkout $desired_branch"
      git checkout -f "$desired_branch" || exit 1
      git merge "$desired_branch" || exit 1 # get incoming changes to a branch
    fi

    new_git_version=`git rev-parse HEAD`
    if [[ "$old_git_version" != "$new_git_version" ]]; then
      echo "got upstream changes, forcing re-configure."
      git clean -f # Throw away local changes; 'already_*' and bak-files for instance.
    else
      echo "fetched no code changes, not forcing reconfigure for that..."
    fi
    cd ..
    touch $to_dir_done_name || exit 1
  fi
}

get_small_touchfile_name() { # have to call with assignment like a=$(get_small...)
  local beginning="$1"
  local extra_stuff="$2"
  local touch_name="${beginning}_$(echo -- $extra_stuff $CFLAGS $LDFLAGS | /usr/bin/env md5sum)" # md5sum to make it smaller, cflags to force rebuild if changes
  touch_name=$(echo "$touch_name" | sed "s/ //g") # md5sum introduces spaces, remove them
  echo "$touch_name" # bash cruddy return system LOL
}

do_autogen() {
  local autogen_name="$1"
  if [[ "$autogen_name" = "" ]]; then
    autogen_name="./autogen.sh"
  fi
  local cur_dir2=$(pwd)
  local english_name=$(basename $cur_dir2)
  local touch_name=$(get_small_touchfile_name autogenned "$autogen_name")
  if [ ! -f "$touch_name" ]; then
    # make uninstall # does weird things when run under ffmpeg src so disabled for now...

    echo "autogenning $english_name ($PWD) as PATH=$mingw_bin_path:\$PATH $autogen_name" # say it now in case bootstrap fails etc.
    rm -f autogenned_* # reset
    "$autogen_name" || exit 1 # not nice on purpose, so that if some other script is running as nice, this one will get priority :)
    touch -- "$touch_name"
  else
    echo "already autogenned $(basename $cur_dir2)"
  fi
}

do_configure() {
  local configure_options="$1"
  local configure_name="$2"
  if [[ "$configure_name" = "" ]]; then
    configure_name="./configure"
  fi
  local cur_dir2=$(pwd)
  local english_name=$(basename $cur_dir2)
  local touch_name=$(get_small_touchfile_name already_configured "$configure_options $configure_name")
  if [ ! -f "$touch_name" ]; then
    # make uninstall # does weird things when run under ffmpeg src so disabled for now...

    echo "configuring $english_name ($PWD) as $ PKG_CONFIG_PATH=$PKG_CONFIG_PATH PATH=$mingw_bin_path:\$PATH $configure_name $configure_options" # say it now in case bootstrap fails etc.
    if [ -f bootstrap ]; then
      ./bootstrap # some need this to create ./configure :|
    fi
    if [[ ! -f $configure_name && -f bootstrap.sh ]]; then # fftw wants to only run this if no configure :|
      ./bootstrap.sh
    fi
    if [[ ! -f $configure_name ]]; then
      autoreconf -fiv # a handful of them require this to create ./configure :|
    fi
    rm -f already_* # reset
    "$configure_name" $configure_options || exit 1 # not nice on purpose, so that if some other script is running as nice, this one will get priority :)
    touch -- "$touch_name"
    echo "doing preventative make clean"
    nice make clean -j $cpu_count # sometimes useful when files change, etc.
  #else
  #  echo "already configured $(basename $cur_dir2)"
  fi
}

do_compile() {
  local compile_source="$1"
  local compile_dest="$2"
  local cur_dir2=$(pwd)

  local compile_source_dir=$(dirname $compile_source)
  local compile_source_name=$(basename $compile_source)
  local compile_source_done="$compile_source_dir/$compile_source_name.done"
  echo "compile_source_done: $compile_source_done"

  if [[ ! -e $compile_source_done ]]; then
    echo
    echo "building $compile_source as $compile_dest"
    echo
    echo ${cross_prefix}g++ $compile_source -o $cur_dir2/$compile_dest 
    nice ${cross_prefix}g++ $compile_source -o $cur_dir2/$compile_dest || exit 1
    touch $compile_source_done || exit 1
  fi
}

do_make() {
  local extra_make_options="$1 -j $cpu_count"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_make "$extra_make_options" )

  if [ ! -f $touch_name ]; then
    echo
    echo "making $cur_dir2 as $ PATH=$mingw_bin_path:\$PATH make $extra_make_options"
    echo
    if [ ! -f configure ]; then
      nice make clean -j $cpu_count # just in case helpful if old junk left around and this is a 're make' and wasn't cleaned at reconfigure time
    fi
    nice make $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already made $(basename "$cur_dir2") ..."
  fi
}

do_make_and_make_install() {
  local extra_make_options="$1"
  do_make "$extra_make_options"
  do_make_install "$extra_make_options"
}

do_make_install() {
  local extra_make_install_options="$1"
  local override_make_install_options="$2" # startingly, some need/use something different than just 'make install'
  if [[ -z $override_make_install_options ]]; then
    local make_install_options="install $extra_make_install_options"
  else
    local make_install_options="$override_make_install_options $extra_make_install_options"
  fi
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$make_install_options")
  if [ ! -f $touch_name ]; then
    echo "make installing $(pwd) as $ PATH=$mingw_bin_path:\$PATH make $make_install_options"
    nice make $make_install_options || exit 1
    touch $touch_name || exit 1
  fi
}

do_cmake() {
  extra_args="$1"
  local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

  if [ ! -f $touch_name ]; then
    rm -f already_* # reset so that make will run again if option just changed
    local cur_dir2=$(pwd)
    echo doing cmake in $cur_dir2 with PATH=$mingw_bin_path:\$PATH with extra_args=$extra_args like this:
    echo ${cmake_command} -G"Unix Makefiles" . -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args
    ${cmake_command} -G"Unix Makefiles" . -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    touch $touch_name || exit 1
  fi
}

do_cmake_from_build_dir() {
  source_dir="$1"
  extra_args="$2"
  local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

  if [ ! -f $touch_name ]; then
    rm -f already_* # reset so that make will run again if option just changed
    local cur_dir2=$(pwd)
    echo doing cmake in $cur_dir2 with PATH=$mingw_bin_path:\$PATH with extra_args=$extra_args like this:
    echo ${cmake_command} -G"Unix Makefiles" $source_dir -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args
    ${cmake_command} -G"Unix Makefiles" $source_dir -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    touch $touch_name || exit 1
  fi
}

do_cmake_and_install() {
  do_cmake "$1"
  do_make_and_make_install
}

apply_patch() {
  local url=$1 # if you want it to use a local file instead of a url one [i.e. local file with local modifications] specify it like file://localhost/full/path/to/filename.patch
  local patch_type=$2
  if [[ -z $patch_type ]]; then
    patch_type="-p0" # some are -p1 unfortunately, git's default
  fi
  local patch_name=$(basename $url)
  local patch_done_name="$patch_name.done"
  if [[ ! -e $patch_done_name ]]; then
    if [[ -f $patch_name ]]; then
      rm $patch_name || exit 1 # remove old version in case it has been since updated on the server...
    fi
    curl -4 --retry 5 $url -O --fail || echo_and_exit "unable to download patch file $url"
    echo "applying patch $patch_name"
    patch $patch_type < "$patch_name" || exit 1
    touch $patch_done_name || exit 1
    rm -f already_ran* # if it's a new patch, reset everything too, in case it's really really really new
  #else
    #echo "patch $patch_name already applied"
  fi
}

echo_and_exit() {
  echo "failure, exiting: $1"
  exit 1
}

# takes a url, output_dir as params, output_dir optional
download_and_unpack_file() {
  url="$1"
  output_name=$(basename $url)
  output_dir="$2"
  if [[ -z $output_dir ]]; then
    output_dir=$(basename $url | sed s/\.tar\.*//) # remove .tar.xx
  fi
  if [ ! -f "$output_dir/unpacked.successfully" ]; then
    echo "downloading $url"
    if [[ -f $output_name ]]; then
      rm $output_name || exit 1
    fi

    #  From man curl
    #  -4, --ipv4
    #  If curl is capable of resolving an address to multiple IP versions (which it is if it is  IPv6-capable),
    #  this option tells curl to resolve names to IPv4 addresses only.
    #  avoid a "network unreachable" error in certain [broken Ubuntu] configurations a user ran into once
    #  -L means "allow redirection" or some odd :|

    curl -4 "$url" --retry 50 -O -L --fail || echo_and_exit "unable to download $url"
    tar -xf "$output_name" || unzip "$output_name" || exit 1
    touch "$output_dir/unpacked.successfully" || exit 1
    rm "$output_name" || exit 1
  fi
}

generic_configure() {
  local extra_configure_options="$1"
  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix --disable-shared --enable-static $extra_configure_options"
}

generic_dll_configure() {
  local extra_configure_options="$1"
  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix --enable-shared --disable-static $extra_configure_options"
}

# params: url, optional "english name it will unpack to"
generic_download_and_configure() {
  local url="$1"
  local english_name="$2"
  if [[ -z $english_name ]]; then
    english_name=$(basename $url | sed s/\.tar\.*//) # remove .tar.xx, take last part of url
  fi
  local extra_configure_options="$3"
  download_and_unpack_file $url $english_name
  cd $english_name || exit "unable to cd, may need to specify dir it will unpack to as parameter"
  generic_configure "$extra_configure_options"
  cd ..
}

# params: url, optional "english name it will unpack to"
generic_download_and_make_and_install() {
  local url="$1"
  local english_name="$2"
  if [[ -z $english_name ]]; then
    english_name=$(basename $url | sed s/\.tar\.*//) # remove .tar.xx, take last part of url
  fi
  local extra_configure_options="$3"
  download_and_unpack_file $url $english_name
  cd $english_name || exit "unable to cd, may need to specify dir it will unpack to as parameter"
  generic_configure "$extra_configure_options"
  do_make_and_make_install
  cd ..
}

generic_dll_download_and_make_and_install() {
  local url="$1"
  local english_name="$2"
  if [[ -z $english_name ]]; then
    english_name=$(basename $url | sed s/\.tar\.*//) # remove .tar.xx, take last part of url
  fi
  local extra_configure_options="$3"
  download_and_unpack_file $url $english_name
  cd $english_name || exit "unable to cd, may need to specify dir it will unpack to as parameter"
  generic_configure "$extra_configure_options"
  do_make_and_make_install
  cd ..
}

do_git_checkout_and_make_install() {
  local url=$1
  local git_checkout_name=$(basename $url | sed s/\.git/_git/) # http://y/abc.git -> abc_git
  do_git_checkout $url $git_checkout_name
  cd $git_checkout_name
    generic_configure_make_install
  cd ..
}

generic_configure_make_install() {
  if [ $# -gt 0 ]; then
    echo "cant pass parameters to this today"
    echo "The following arguments where passed: ${@}"
    exit 1
  fi
  generic_configure # no parameters, force myself to break it up if needed
  do_make_and_make_install
}

gen_ld_script() {
  lib=$mingw_w64_x86_64_prefix/lib/$1
  lib_s="$2"
  if [[ ! -f $mingw_w64_x86_64_prefix/lib/lib$lib_s.a ]]; then
    echo "Generating linker script $lib: $2 $3"
    mv -f $lib $mingw_w64_x86_64_prefix/lib/lib$lib_s.a
    echo "GROUP ( -l$lib_s $3 )" > $lib
  fi
}

reset_cflags() {
  export CFLAGS=$original_cflags
}

build_gmp() {
  download_and_unpack_file https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
  cd gmp-6.1.2
    sudo update-binfmts --disable wine || exit 1
    #export CC_FOR_BUILD=/usr/bin/gcc # Are these needed?
    #export CPP_FOR_BUILD=usr/bin/cpp
    generic_configure "ABI=$bits_target"
    #unset CC_FOR_BUILD
    #unset CPP_FOR_BUILD
    do_make_and_make_install
    sudo update-binfmts --enable wine || exit 1 
  cd ..
}

build_mpfr() {
  download_and_unpack_file https://www.mpfr.org/mpfr-3.1.5/mpfr-3.1.5.tar.xz
  cd mpfr-3.1.5
    #export CC_FOR_BUILD=/usr/bin/gcc # Are these needed?
    #export CPP_FOR_BUILD=usr/bin/cpp
    generic_configure "ABI=$bits_target"
    #unset CC_FOR_BUILD
    #unset CPP_FOR_BUILD
    do_make_and_make_install
  cd ..
}

build_mpc() {
  download_and_unpack_file http://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
  cd mpc-1.0.3
    #export CC_FOR_BUILD=/usr/bin/gcc # Are these needed?
    #export CPP_FOR_BUILD=usr/bin/cpp
    generic_configure "ABI=$bits_target"
    #unset CC_FOR_BUILD
    #unset CPP_FOR_BUILD
    do_make_and_make_install
  cd ..
}

build_isl() {
  download_and_unpack_file http://libisl.sourceforge.io/isl-0.18.tar.xz
  cd isl-0.18
    #export CC_FOR_BUILD=/usr/bin/gcc # Are these needed?
    #export CPP_FOR_BUILD=usr/bin/cpp
    generic_configure --with-piplib=no "ABI=$bits_target"
    #unset CC_FOR_BUILD
    #unset CPP_FOR_BUILD
    do_make_and_make_install
  cd ..
}

build_boost() {
  download_and_unpack_file https://sourceforge.net/projects/boost/files/boost/1.65.1/boost_1_65_1.tar.gz
  cd boost_1_65_1
  apply_patch file://$patch_dir/boost_asm.diff "-p1"
  local touch_name=$(get_small_touchfile_name already_ran_bootstrap "")
  if [ ! -f $touch_name ]; then
    echo "using gcc : : ${cross_prefix}g++ ;" > user-config.jam
    ./bootstrap.sh || exit 1
    touch $touch_name || exit 1
  fi
  local touch_name=$(get_small_touchfile_name already_ran_b2 "")
  if [ ! -f $touch_name ]; then
    ./b2 --user-config=user-config.jam toolset=gcc-mingw target-os=windows threading=multi threadapi=win32 link=static --prefix=$mingw_w64_x86_64_prefix --without-mpi --without-python variant=release address-model=$bits_target install || exit 1
    #./b2 --user-config=user-config.jam toolset=gcc-mingw target-os=windows threading=multi threadapi=win32 link=static --prefix=$mingw_w64_x86_64_prefix --without-mpi --without-python variant=debug address-model=$bits_target install || exit 1
    #CROSSCC=gcc CROSSCXX=g++ CC=${cross_prefix}gcc CXX=${cross_prefix}g++ BOOST_JAM_OS=NT CFLAGS="${CFLAGS} -DNT" ./bootstrap.sh --prefix=$mingw_w64_x86_64_prefix --with-toolset=crosscc
    #CC=${cross_prefix}gcc CXX=${cross_prefix}g++ BOOST_JAM_OS=NT CFLAGS="${CFLAGS} -DNT" ./bootstrap.sh --prefix=$mingw_w64_x86_64_prefix --with-toolset=cc
    #CC=${cross_prefix}gcc CXX=${cross_prefix}g++ BOOST_JAM_OS=NT CFLAGS="${CFLAGS} -DNT" ./b2 --prefix=$mingw_w64_x86_64_prefix
    touch $touch_name || exit 1
  fi
  cd ..
}

build_zlib() {
  download_and_unpack_file https://github.com/madler/zlib/archive/v1.2.11.tar.gz zlib-1.2.11
  cd zlib-1.2.11
    local make_options
    if [[ $compiler_flavors == "native" ]]; then
      export CFLAGS="$CFLAGS -fPIC" # For some reason glib needs this even though we build a static library
    else
      export ARFLAGS=rcs # Native can't take ARFLAGS; https://stackoverflow.com/questions/21396988/zlib-build-not-configuring-properly-with-cross-compiler-ignores-ar
    fi
    do_configure "--prefix=$mingw_w64_x86_64_prefix --static"
    do_make_and_make_install "$make_prefix_options ARFLAGS=rcs"
    if [[ $compiler_flavors == "native" ]]; then
      reset_cflags
    else
      unset ARFLAGS
    fi
  cd ..
}

build_bash() {
  download_and_unpack_file ftp://ftp.gnu.org/gnu/bash/bash-4.4.18.tar.gz
  cd bash-4.4.18
    generic_configure
    do_make_and_make_install
  cd ..
}

find_all_build_exes() {
  local found=""
# NB that we're currently in the sandbox dir...
  for file in `find . -name ffmpeg.exe` `find . -name ffmpeg_g.exe` `find . -name ffplay.exe` `find . -name MP4Box.exe` `find . -name mplayer.exe` `find . -name mencoder.exe` `find . -name avconv.exe` `find . -name avprobe.exe` `find . -name x264.exe` `find . -name writeavidmxf.exe` `find . -name writeaviddv50.exe` `find . -name rtmpdump.exe` `find . -name x265.exe` `find . -name ismindex.exe` `find . -name dvbtee.exe` `find . -name boxdumper.exe` `find . -name muxer.exe ` `find . -name remuxer.exe` `find . -name timelineeditor.exe` `find . -name lwcolor.auc` `find . -name lwdumper.auf` `find . -name lwinput.aui` `find . -name lwmuxer.auf` `find . -name vslsmashsource.dll`; do
    found="$found $(readlink -f $file)"
  done

  # bash recursive glob fails here again?
  for file in `find . -name vlc.exe | grep -- -`; do
    found="$found $(readlink -f $file)"
  done
  echo $found # pseudo return value...
}

build_dependencies() {
  echo "Building retro86 dependency libraries..."

  if [ ! -d ../../MPW-GM ]; then
	  if [ -f ../../mpw-gm.img__0.bin ]; then
		  mkdir -p tmp || exit 1
		  NODE_PATH=$(npm root -g) node ../../ndif_research/decompress.js ../../mpw-gm.img__0.bin ../../mpw-gm.ro.img || exit 1
                  sudo mount -t hfs -o loop ../../mpw-gm.ro.img tmp || exit 1
		  cp -r tmp/MPW-GM ../../MPW-GM || exit 1
		  sudo umount tmp || exit 1
		  rmdir tmp || exit 1
	  else
		  echo 'Failed to find a MPW-GM image file, please put one into the Retro86 build directory. The following images are handled: mpw-gm.img__0.bin'
		  exit 1
	  fi
  fi

  build_gmp
  build_mpfr
  build_mpc
  build_isl
  build_boost
  build_zlib
  #build_bash
  #cat mpw-gm.img__0.bin | unbin - || exit 1
}

build_retro86() {
  #rm dosbox.diff*
  if [[ ! -e Retro68.done ]]; then
    rm -rf Retro68-build
  fi
  do_git_checkout https://github.com/autc04/Retro68.git Retro68 6e00994e45cb09231d6fff08d9c2680a1834002c
  do_compile $patch_dir/wineFindStrWorkarround.c Retro68/gcc/gcc/wineFindStrWorkarround.exe
  cp $patch_dir/exec-tool.c.in Retro68/gcc/gcc/exec-tool.c.in
  cp $patch_dir/exec-tool.cmd.in Retro68/gcc/gcc/exec-tool.cmd.in
  #apply_patch file://$patch_dir/dosbox.diff
  cd Retro68
    mkdir -p ~/.wine/drive_c/temp
    apply_patch file://$patch_dir/Retro68-build-toolchain.bash.diff "-p0"
    apply_patch file://$patch_dir/Retro68-build-host.diff "-p1"
    cd hfsutils
    apply_patch file://$patch_dir/hfsutils.diff "-p1"
    cd ../gcc
    apply_patch file://$patch_dir/gcc-Makefile.tpl.diff "-p0"
    apply_patch file://$patch_dir/gcc-Makefile.in.diff "-p0"
    apply_patch file://$patch_dir/gcc-config-ml.in.diff "-p0"
    cd gcc
    apply_patch file://$patch_dir/gcc-gcc-exec-tool.in.diff "-p0"
    apply_patch file://$patch_dir/gcc-gcc-configure.ac.diff "-p0"
    apply_patch file://$patch_dir/gcc-gcc-configure.diff "-p0"
    apply_patch file://$patch_dir/gcc-gcc-Makefile.in.diff "-p0"
    cd ../libgcc
    apply_patch file://$patch_dir/gcc-libgcc-configure.diff "-p0"
    apply_patch file://$patch_dir/gcc-libgcc-Makefile.in.diff "-p0"
    apply_patch file://$patch_dir/gcc-libgcc-fixed-obj.mk.diff "-p0"
    apply_patch file://$patch_dir/gcc-libgcc-shared-object.mk.diff "-p0"
    apply_patch file://$patch_dir/gcc-libgcc-siditi-object.mk.diff "-p0"
    apply_patch file://$patch_dir/gcc-libgcc-static-object.mk.diff "-p0"
    cd ../libatomic
    apply_patch file://$patch_dir/gcc-libatomic-configure.diff "-p0"
    cd ../libitm
    apply_patch file://$patch_dir/gcc-libitm-configure.diff "-p0"
    cd ../libgomp
    apply_patch file://$patch_dir/gcc-libgomp-configure.diff "-p0"
    cd ../libada
    apply_patch file://$patch_dir/gcc-libada-configure.diff "-p0"
    cd ../zlib
    apply_patch file://$patch_dir/gcc-zlib-configure.diff "-p0"
    cd ../libffi
    apply_patch file://$patch_dir/gcc-libffi-configure.diff "-p0"
    cd ../libphobos
    apply_patch file://$patch_dir/gcc-libphobos-configure.diff "-p0"
    cd ../libhsail-rt
    apply_patch file://$patch_dir/gcc-libhsail-rt-configure.diff "-p0"
    cd ../libgo
    apply_patch file://$patch_dir/gcc-libgo-configure.diff "-p0"
    cd ../libobjc
    apply_patch file://$patch_dir/gcc-libobjc-configure.diff "-p0"
    cd ../libgfortran
    apply_patch file://$patch_dir/gcc-libgfortran-configure.diff "-p0"
    cd ../libquadmath
    apply_patch file://$patch_dir/gcc-libquadmath-configure.diff "-p0"
    cd ../libbacktrace
    apply_patch file://$patch_dir/gcc-libbacktrace-configure.diff "-p0"
    cd ../newlib
    apply_patch file://$patch_dir/gcc-newlib-configure.diff "-p0"
    cd ../libssp
    apply_patch file://$patch_dir/gcc-libssp-configure.diff "-p0"
    cd ../liboffloadmic
    apply_patch file://$patch_dir/gcc-liboffloadmic-configure.diff "-p0"
    cd ../libvtv
    apply_patch file://$patch_dir/gcc-libvtv-configure.diff "-p0"
    cd ../libsanitizer
    apply_patch file://$patch_dir/gcc-libsanitizer-configure.diff "-p0"
    cd ../libstdc++-v3
    apply_patch file://$patch_dir/gcc-libstdc++-v3-configure.diff "-p0"
    cd include/bits
    apply_patch file://$patch_dir/gcc-libstdc++-v3-include-bits-random.diff "-p0"
    cd ../..
    cd ../..
    if [[ ! -e PEFTools/wait.h ]]; then
      cp $externals_dir/sys_wait_h/sys/wait.h PEFTools/wait.h || exit 1
    fi
    if [[ ! -e PEFTools/mman.h ]]; then
      cp $externals_dir/mman-win32/mman.h PEFTools/mman.h || exit 1
    fi
    if [[ ! -e PEFTools/mman.c ]]; then
      cp $externals_dir/mman-win32/mman.c PEFTools/mman.c || exit 1
    fi
    if [[ ! -e libelf/src/mman.h ]]; then
      cp $externals_dir/mman-win32/mman.h libelf/src/mman.h || exit 1
    fi
    if [[ ! -e libelf/src/mman.c ]]; then
      cp $externals_dir/mman-win32/mman.c libelf/src/mman.c || exit 1
    fi
    if [[ ! -e libelf/src/fcntl.h ]]; then
      cp $externals_dir/fcntl_windows/fcntl.h libelf/src/fcntl.h || exit 1
    fi
    if [[ ! -e libelf/src/fcntl.c ]]; then
      cp $externals_dir/fcntl_windows/fcntl.c libelf/src/fcntl.c || exit 1
    fi
    if [[ ! -e libelf/src/ioinfo.h ]]; then
      cp $externals_dir/fcntl_windows/IOINFO.H libelf/src/ioinfo.h || exit 1
    fi
    if [[ ! -e libelf/src/fchmod.h ]]; then
      cp $externals_dir/fchmod_windows/fchmod.h libelf/src/fchmod.h || exit 1
    fi
    if [[ ! -e libelf/src/fchmod.cpp ]]; then
      cp $externals_dir/fchmod_windows/fchmod.cpp libelf/src/fchmod.cpp || exit 1
    fi
    if [[ ! -e libelf/src/fallocate.h ]]; then
      cp $externals_dir/posix_fallocate_windows/fallocate.h libelf/src/fallocate.h || exit 1
    fi
    if [[ ! -e libelf/src/fallocate.cpp ]]; then
      cp $externals_dir/posix_fallocate_windows/fallocate.cpp libelf/src/fallocate.cpp || exit 1
    fi
    if [[ ! -e libelf/src/sysconf.h ]]; then
      cp $externals_dir/sysconf_windows/sysconf.h libelf/src/sysconf.h || exit 1
    fi
    if [[ ! -e libelf/src/sysconf.cpp ]]; then
      cp $externals_dir/sysconf_windows/sysconf.cpp libelf/src/sysconf.cpp || exit 1
    fi
    if [[ ! -e Elf2Mac/err.c ]]; then
      cp $externals_dir/err_windows/err.c Elf2Mac/err.c || exit 1
    fi
    if [[ ! -e Elf2Mac/err.h ]]; then
      cp $externals_dir/err_windows/err.h Elf2Mac/err.h || exit 1
    fi
    if [[ ! -e Elf2Mac/wait.h ]]; then
      cp $externals_dir/sys_wait_h/sys/wait.h Elf2Mac/wait.h || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/wait.h ]]; then
      cp $externals_dir/sys_wait_h/sys/wait.h LaunchAPPL/Client/wait.h || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/env.h ]]; then
      cp $externals_dir/env_windows/env.h LaunchAPPL/Client/env.h || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/env.c ]]; then
      cp $externals_dir/env_windows/env.c LaunchAPPL/Client/env.c || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/pspawn.h ]]; then
      cp $externals_dir/pspawn/pspawn.h LaunchAPPL/Client/pspawn.h || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/pspawn.c ]]; then
      cp $externals_dir/pspawn/pspawn.c LaunchAPPL/Client/pspawn.c || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/tpspawn.c ]]; then
      cp $externals_dir/pspawn/tpspawn.c LaunchAPPL/Client/tpspawn.c || exit 1
    fi
    if [[ ! -e LaunchAPPL/Client/wpspawn.c ]]; then
      cp $externals_dir/pspawn/wpspawn.c LaunchAPPL/Client/wpspawn.c || exit 1
    fi
    if [[ ! -e $patch_dir/wine_tmp_path.reg.done ]]; then
      wine regedit $patch_dir/wine_tmp_path.reg || exit 1
      touch $patch_dir/wine_tmp_path.reg.done || exit 1
    fi
    if [[ ! -e gcc/gcc/Makefile.in.SELFTEST.done ]]; then
      sed -i -e 's#SELFTEST_FLAGS = -nostdinc -x c /dev/null -S -o /dev/null \\#SELFTEST_FLAGS = -nostdinc -x c nul -S -o nul \\#g' gcc/gcc/Makefile.in || exit 1
      touch gcc/gcc/Makefile.in.SELFTEST.done || exit 1
    fi
    export SDL_CONFIG="${cross_prefix}sdl-config"
    export CC=${cross_prefix}gcc
    export CXX=${cross_prefix}g++
    export AR=${cross_prefix}ar
    export RANLIB=${cross_prefix}ranlib
    export LIBS=""
    #export LIBS="-lSDL_net -liphlpapi -lwsock32 -lws2_32 -lSDL_sound -lspeex -lmodplug -lmikmod -lsmpeg -lFLAC -lvorbisfile -lvorbis -logg -lstdc++"
    #export LIBS="-lspeex -lmodplug -lmikmod -lsmpeg -lFLAC -lvorbisfile -lvorbis -logg -lstdc++"
    export LDFLAGS="-static-libgcc -static-libstdc++ -s"

    if [ ! -d InterfacesAndLibraries/PPCLibraries ]; then
	    echo cp -r ../../../MPW-GM/Interfaces\&Libraries/Libraries/PPCLibraries InterfacesAndLibraries/PPCLibraries
	    cp -r ../../../MPW-GM/Interfaces\&Libraries/Libraries/PPCLibraries InterfacesAndLibraries/PPCLibraries
    fi
    if [ ! -d InterfacesAndLibraries/Libraries ]; then
	    echo cp -r ../../../MPW-GM/Interfaces\&Libraries/Libraries/Libraries InterfacesAndLibraries/Libraries
	    cp -r ../../../MPW-GM/Interfaces\&Libraries/Libraries/Libraries InterfacesAndLibraries/Libraries
    fi
    if [ ! -d InterfacesAndLibraries/SharedLibraries ]; then
	    echo cp -r ../../../MPW-GM/Interfaces\&Libraries/Libraries/SharedLibraries InterfacesAndLibraries/SharedLibraries
	    cp -r ../../../MPW-GM/Interfaces\&Libraries/Libraries/SharedLibraries InterfacesAndLibraries/SharedLibraries
    fi
    if [ ! -d InterfacesAndLibraries/CIncludes ]; then
	    echo cp -r ../../../MPW-GM/Interfaces\&Libraries/Interfaces/CIncludes InterfacesAndLibraries/CIncludes
	    cp -r ../../../MPW-GM/Interfaces\&Libraries/Interfaces/CIncludes InterfacesAndLibraries/CIncludes
    fi
    if [ ! -d InterfacesAndLibraries/RIncludes ]; then
	    echo cp -r ../../../MPW-GM/Interfaces\&Libraries/Interfaces/RIncludes InterfacesAndLibraries/RIncludes
	    cp -r ../../../MPW-GM/Interfaces\&Libraries/Interfaces/RIncludes InterfacesAndLibraries/RIncludes
    fi
    chmod a+x ./build-toolchain.bash || exit 1
    cd ..
    mkdir -p Retro68-build
    export WINEPATHPOST="$(winepath -w $mingw_bin_path);$(winepath -w $mingw_w64_x86_64_prefix)"
    echo "WINEPATHPOST: $WINEPATHPOST"
    cd Retro68-build
    if [[ ! -e build-toolchain.bash.m68k ]]; then
      ../Retro68/build-toolchain.bash --cross-prefix=${cross_prefix} --host=$host_target --host-cxx-compiler=${cross_prefix}g++ --host-c-compiler=${cross_prefix}gcc --boost-rootdir=$mingw_w64_x86_64_prefix --boost-libdir=$mingw_w64_x86_64_prefix/lib --stop-after-68k-gcc || exit 1 # not nice on purpose, so that if some other script is running as nice, this one will get priority :)
      touch build-toolchain.bash.m68k
    fi
    if [[ ! -e build-toolchain.bash.ppc ]]; then
      ../Retro68/build-toolchain.bash --cross-prefix=${cross_prefix} --host=$host_target --host-cxx-compiler=${cross_prefix}g++ --host-c-compiler=${cross_prefix}gcc --boost-rootdir=$mingw_w64_x86_64_prefix --boost-libdir=$mingw_w64_x86_64_prefix/lib --skip-68k-gcc-build --stop-after-ppc-gcc || exit 1 # not nice on purpose, so that if some other script is running as nice, this one will get priority :)
      touch build-toolchain.bash.ppc
    fi
    if [[ ! -e build-toolchain.bash.tools ]]; then
      ../Retro68/build-toolchain.bash --cross-prefix=${cross_prefix} --host=$host_target --host-cxx-compiler=${cross_prefix}g++ --host-c-compiler=${cross_prefix}gcc --boost-rootdir=$mingw_w64_x86_64_prefix --boost-libdir=$mingw_w64_x86_64_prefix/lib --skip-68k-gcc-build --skip-ppc-gcc-build || exit 1 # not nice on purpose, so that if some other script is running as nice, this one will get priority :)
      touch build-toolchain.bash.tools
    fi
    unset LDFLAGS
    unset LIBS
    unset SDL_CONFIG
    unset CC
    unset CXX
    unset AR
    unset RANLIB
  cd ..
}

build_apps() {
  echo "Building retro86..."
  build_retro86
}

# set some parameters initial values
cur_dir="$(pwd)/sandbox"
patch_dir="$(pwd)/patches"
externals_dir="$(pwd)/externals"
cpu_count="$(grep -c processor /proc/cpuinfo 2>/dev/null)" # linux cpu count
if [ -z "$cpu_count" ]; then
  cpu_count=`sysctl -n hw.ncpu | tr -d '\n'` # OS X
  if [ -z "$cpu_count" ]; then
    echo "warning, unable to determine cpu count, defaulting to 1"
    cpu_count=1 # else default to just 1, instead of blank, which means infinite
  fi
fi
original_cpu_count=$cpu_count # save it away for some that revert it temporarily

set_box_memory_size_bytes
if [[ $box_memory_size_bytes -lt 600000000 ]]; then
  echo "your box only has $box_memory_size_bytes, 512MB (only) boxes crash when building cross compiler gcc, please add some swap" # 1G worked OK however...
  exit 1
fi

if [[ $box_memory_size_bytes -gt 2000000000 ]]; then
  gcc_cpu_count=$cpu_count # they can handle it seemingly...
else
  echo "low RAM detected so using only one cpu for gcc compilation"
  gcc_cpu_count=1 # compatible low RAM...
fi

# variables with their defaults
original_cflags='-mtune=generic -O3' # high compatible by default, see #219, some other good options are listed below, or you could use -march=native to target your local box:

# parse command line parameters, if any
while true; do
  case $1 in
    -h | --help ) echo "available option=default_value:
      --gcc-cpu-count=[number of cpu cores set it higher than 1 if you have multiple cores and > 1GB RAM, this speeds up initial cross compiler build. FFmpeg build uses number of cores no matter what]
      --sandbox-ok=n [skip sandbox prompt if y]
      -d [meaning \"defaults\" skip all prompts, just build ffmpeg static with some reasonable defaults like no git updates]
      -a 'build all' builds ffmpeg, mplayer, vlc, etc. with all fixings turned on
      --compiler-flavors=[multi,win32,win64] [default prompt, or skip if you already have one built, multi is both win32 and win64]
      --cflags=[default is $original_cflags, which works on any cpu, see README for options]
      --prefer-stable=y build a few libraries from releases instead of git master
      --high-bitdepth=n Enable high bit depth for x264 (10 bits) and x265 (10 and 12 bits, x64 build. Not officially supported on x86 (win32), but enabled by disabling its assembly).
      --debug Make this script  print out each line as it executes
       "; exit 0 ;;
    --gcc-cpu-count=* ) gcc_cpu_count="${1#*=}"; shift ;;
    --cflags=* )
       original_cflags="${1#*=}"; echo "setting cflags as $original_cflags"; shift ;;
    # this doesn't actually "build all", like doesn't build 10 high-bit LGPL ffmpeg, but it does exercise the "non default" type build options...
    -a         ) compiler_flavors="multi"; 
                 shift ;;
    -d         ) gcc_cpu_count=$cpu_count; compiler_flavors="win32"; shift ;;
    --compiler-flavors=* ) compiler_flavors="${1#*=}"; shift ;;
    --debug ) set -x; shift ;;
    -- ) shift; break ;;
    -* ) echo "Error, unknown option: '$1'."; exit 1 ;;
    * ) break ;;
  esac
done

reset_cflags # also overrides any "native" CFLAGS, which we may need if there are some 'linux only' settings in there
check_missing_packages # do this first since it's annoying to go through prompts then be rejected
check_missing_node_packages # do this next since it's annoying to go through prompts then be rejected
intro # remember to always run the intro, since it adjust pwd
install_cross_compiler

export PKG_CONFIG_LIBDIR= # disable pkg-config from finding [and using] normal linux system installed libs [yikes]

if [[ $OSTYPE == darwin* ]]; then
  # mac add some helper scripts
  mkdir -p mac_helper_scripts
  cd mac_helper_scripts
    if [[ ! -x readlink ]]; then
      # make some scripts behave like linux...
      curl -4 file://$patch_dir/md5sum.mac --fail > md5sum  || exit 1
      chmod u+x ./md5sum
      curl -4 file://$patch_dir/readlink.mac --fail > readlink  || exit 1
      chmod u+x ./readlink
    fi
    export PATH=`pwd`:$PATH
  cd ..
fi

original_path="$PATH"
if [[ $compiler_flavors == "multi" || $compiler_flavors == "win32" ]]; then
  echo
  echo "Starting 32-bit builds..."
  host_target='i686-w64-mingw32'
  mingw_w64_x86_64_prefix="$cur_dir/cross_compilers/mingw-w64-i686/$host_target"
  mingw_bin_path="$cur_dir/cross_compilers/mingw-w64-i686/bin"
  export PKG_CONFIG_PATH="$mingw_w64_x86_64_prefix/lib/pkgconfig"
  export PATH="$mingw_bin_path:$original_path"
  bits_target=32
  cross_prefix="$mingw_bin_path/i686-w64-mingw32-"
  make_prefix_options="CC=${cross_prefix}gcc AR=${cross_prefix}ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=${cross_prefix}ranlib LD=${cross_prefix}ld LINK=${cross_prefix}gcc STRIP=${cross_prefix}strip CXX=${cross_prefix}g++ AS=${cross_prefix}as CPP=${cross_prefix}cpp"
  mkdir -p win32
  cd win32
    {
      build_dependencies 
      build_apps
    }
    sudo update-binfmts --enable wine || exit 1
  cd ..
fi

if [[ $compiler_flavors == "multi" || $compiler_flavors == "win64" ]]; then
  echo
  echo "**************Starting 64-bit builds..." # make it have a bit easier to you can see when 32 bit is done
  host_target='x86_64-w64-mingw32'
  mingw_w64_x86_64_prefix="$cur_dir/cross_compilers/mingw-w64-x86_64/$host_target"
  mingw_bin_path="$cur_dir/cross_compilers/mingw-w64-x86_64/bin"
  export PKG_CONFIG_PATH="$mingw_w64_x86_64_prefix/lib/pkgconfig"
  export PATH="$mingw_bin_path:$original_path"
  bits_target=64
  cross_prefix="$mingw_bin_path/x86_64-w64-mingw32-"
  make_prefix_options="CC=${cross_prefix}gcc AR=${cross_prefix}ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=${cross_prefix}ranlib LD=${cross_prefix}ld LINK=${cross_prefix}gcc STRIP=${cross_prefix}strip CXX=${cross_prefix}g++ AS=${cross_prefix}as CPP=${cross_prefix}cpp"
  mkdir -p win64
  cd win64
    {
      build_dependencies 
      build_apps
    }
    sudo update-binfmts --enable wine || exit 1
  cd ..
fi

echo "searching for all local exe's (some may not have been built this round, NB)..."
for file in $(find_all_build_exes); do
  echo "built $file"
done
