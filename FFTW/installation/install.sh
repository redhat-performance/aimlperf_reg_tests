#!/bin/bash

# This script installs the rpms built using the 'build.sh' script in this folder
usage() {
    echo "Usage: $0 [-h] [-i install_path] [-r rpm_path] [-u] [-s] [-b] [-d] [-l log_filename] [-f CFLAGS]"
    echo "  -h  Help. Display the usage."
    echo "  -i  Path to install FFTW. (Default: /usr/lib)"
    echo "  -r  Path to FFTW rpms. (Default: /root/rpmbuild/RPMS)"
    echo "  -u  Update existing FFTW installation."
    echo "  -s  Run build with sudo. (Use this if you're running this script under root)."
    echo "  -b  Build FFTW."
    echo "  -d  Use default rpmbuild CFLAGS for compiling FFTW. Either use this option or -f, but not both."
    echo "  -l  The resulting build logs will be saved to a file with this name. (Default: fftw_build.log)"
    echo "  -f  Custom CFLAGS for compiling FFTW. Either use this option or -d, but not both."
    exit
}

# Set default values
build_log="fftw_build.log"
build=0
update=0
rpm_path="/root/rpmbuild/RPMS"
install_path=/usr/lib64
sudo=0

options=":hbdl:f:i:r:"
while getopts "$options" x
do
    case "$x" in
      h)  
          usage
          ;;
      b)
          build=1
          ;;
      i)
          install_path=${OPTARG}
          ;;
      r)
          rpm_path=${OPTARG}
          ;;
      d)  
          dcflags="-O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fexceptions -fstack-protector-strong -grecord-gcc-switches %{_hardened_cflags} %{_annotated_cflags}"
          ;;
      l)  
          build_log=${OPTARG}
          ;;
      f)  
          ccflags=${OPTARG}
          ;;
      u)
          update=1
          ;;
      s)
          sudo=1
          ;;
      *)  
          usage
          ;;
    esac
done
shift $((OPTIND-1))

# Check if FFTW is already installed and if we want to update the installation
if [ "$update" == 0 ]; then
    fftw_libraries=$(ls $install_path | grep "libfftw*.so")
    num_fftw_libraries=${#fftw_libraries}
    if [ $num_fftw_libraries > 0 ]; then
        echo "ERROR: FFTW libraries are already installed to $install_path. Use option -u to overwrite these libraries, or choose a different install path."
        usage
    fi
fi

# If user wants to build FFTW...
if [ "$build" == 1 ]; then
    echo "Building FFTW..."
    if [ -z "$dcflags" ] && [ -z "$ccflags" ]; then
        echo "ERROR: When using option -b to build FFTW, you must set the CFLAGS using -d or -f."
        usage
    else if [ ! -z "$dcflags" ] && [ ! -z "$ccflags" ]; then
        echo "ERROR: When using option -b to build FFTW, you cannot use both -d and -f at the same time. Use one or the other."
        usage
    elif [ ! -z "$dcflags" ]; then
	if [ $EUID == 0 ] && [ $sudo == 0 ]; then
	    echo "ERROR: Attempting to run this script under root. This can be dangerous. Override this message using the option -s or switch to non-root user."
	    usage
	elif [ $EUID == 0 ]; then
            sh ./build.sh -s -f $ccflags -l $build_log
        else
            sh ./build.sh -f $ccflags -l $build_log
        fi
    else
	if [ $EUID == 0 ] && [ $sudo == 0 ]; then
	    echo "ERROR: Attempting to run this script under root. This can be dangerous. Override this message using the option -s or switch to non-root user."
	    usage
	elif [ $EUID == 0 ]; then
            sh ./build.sh -s -d -l $build_log
        else
            sh ./build.sh -d -l $build_log
        fi
    fi
fi

# Install FFTW rpms from the x86_64 folder
if [ ! -d "$rpm_path" ]; then
    echo "ERROR: Invalid rpm path $rpm_path. Path does not exist!"
    exit
elif [ ! -d "$rpm_path/x86_64" ]; then
    echo "ERROR: Missing x86_64 rpm folder. Layout must be 'rpm_path/x86_64' and 'rpm_path/noarch'."
    exit
elif [ !-d "$rpm_path/noarch" ]; then
    echo "ERROR: Missing noarch rpm folder. Layout must be 'rpm_path/x86_64' and 'rpm_path/noarch'."
    exit
fi
cd $rpm_path/x86_64
for f in fftw*.rpm
do
    rpm -Uvh -r $install_path $f
done

# Finally, install the FFTW rpms from the noarch folder
cd ../noarch
for f in fftw*.rpm
do
    rpm -Uvh -r $install_path $f
done

echo "Installation complete! FFTW successfully installed to $install_path."
