#!/bin/bash
# This script builds a custom or default FFTW using rpmbuild

usage() {
    echo "Usage: $0 [-h] [-d] [-s] [-l log_filename] [-c CFLAGS] [-f FFTW_flags]"
    echo "  -h  Help. Display the usage."
    echo "  -d  Use default rpmbuild CFLAGS for compiling FFTW. Either use this option or -f, but not both."
    echo "  -s  Run build with sudo. (Use this if you're running this script under root)."
    echo "  -l  The resulting build logs will be saved to a file with this name. (Default: fftw_build.log)"
    echo "  -c  Custom CFLAGS for compiling FFTW. Either use this option or -d, but not both."
    echo "  -f  FFTW build flags to use. (Default --enable-sse2 --enable-avx --enable-fma) (See: http://www.fftw.org/fftw3_doc/Installation-on-Unix.html)"
    exit
}

# Set default values
build_log="fftw_build.log"
fftw_flags="--enable-sse2 --enable-avx --enable-fma"
sudo=0

options=":hdsl:f:"
while getopts "$options" x
do
    case "$x" in
      h)
          usage
          ;;
      d)
          dcflags="-O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fexceptions -fstack-protector-strong -grecord-gcc-switches %{_hardened_cflags} %{_annotated_cflags}"
          ;;
      l)
          build_log=${OPTARG}
          ;;
      c)
          ccflags=${OPTARG}
          ;;
      f)
          fftw_flags=${OPTARG}
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

# Check if this script is being called by root. If so, we don't want to make any changes to root with rpmbuild unless the user specifically wants to
if [ $EUID == 0 ] && [ $sudo == 0 ]; then
    echo "ERROR: Attempting to run this script under root. This can be dangerous. Override this message using the option -s or switch to non-root user."
    usage
fi

# Make sure that the user defines CFLAGS
if [ -z "$dcflags" ] && [ -z "$ccflags" ]; then
    echo "ERROR: You must set which CFLAGS to use. Either use -d or -f to set CFLAGS."
    usage
fi

# This check is to make sure that the user doesn't accidentally use -d and -f together
if [ ! -z "$dcflags" ] && [ ! -z "$ccflags" ]; then
    echo "ERROR: Cannot use both -d and -f at the same time. Choose one or the other."
    usage
fi

# If the user says not to use the default flags, then set CFLAGS to be the value of parameter -f; otherwise, set CFLAGS to the default flags seen in /usr/lib/rpm/redhat/macros
if [ -z "$dcflags" ]; then
    cflags=$ccflags
else
    cflags=$dcflags
fi

echo "Using the following CFLAGS:"
echo $cflags
echo ""
echo "Using the following FFTW build flags:"
echo $fftw_flags
echo ""
echo "Saving results to '$build_log'"
echo ""

# Install necessary requirements
dnf clean all 
dnf -y install automake \
               cpp \
               diffutils \
               environment-modules \
               gcc \
               gcc-c++ \
               gcc-gfortran \
               libgcc \
               libgfortran \
               libgomp \
               libquadmath \
               libtool \
               make \
               mpich-devel \
               openmpi \
               openmpi-devel \
               opensm \
               opensm-devel \
               opensm-libs \
               python3-rpm \
               rpmdevtools \
               rpm-devel \
               rpm-libs \
               rpmlint \
               time \
               wget \
    --setopt=install_weak_deps=False

# Set up rpmbuild tree if it does not exist
if [ ! -d "/root/rpmbuild" ]; then
    rpmdev-setuptree
fi

# Get spec and tar files, then move to the rmpbuild tree
cd /tmp
rm fftw-3.3.5-11.el8.src.rpm #if an existing fftw source rpm exists, remove it.
wget http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/fftw/3.3.5/11.el8/src/fftw-3.3.5-11.el8.src.rpm
rpm2cpio fftw-3.3.5-11.el8.src.rpm | cpio -civ
mv fftw.spec /root/rpmbuild/SPECS
mv fftw-3.3.5.tar.gz /root/rpmbuild/SOURCES
rm fftw-3.3.5-11.el8.src.rpm #clean up

# To build fftw with rpmbuild, we need the environment-modules package to create "module" for "module load" etc
. /usr/share/Modules/init/bash

# Update CFLAGS in /usr/lib/rpm/redhat/macros
sed -i '/^%__global_compiler_flags.*/s/^/#/' /usr/lib/rpm/redhat/macros #Comment out existing CFLAGS lines
sed -i "/.*%__global_compiler_flags.*/a %__global_compiler_flags ${cflags}" /usr/lib/rpm/redhat/macros #add the new CFLAGS

# Prepare to edit fftw.spec to use our new FFTW build flags
cd /root/rpmbuild/SPECS

# Update FFTW build flags
sed -i "318s|.*prec_flags.*| prec_flags[i]+=\"${fftw_flags}\"|" fftw.spec

# [OPTIONAL] Now update to allow for mpirun to run as root
if [ "$sudo" == 1 ]; then
    sed -i '367 i\   if [ "$mpi" == "mpich" ]; then ROOT_MPIRUN="mpirun"; else ROOT_MPIRUN="mpirun --allow-run-as-root"; fi' fftw.spec && \
    sed -i '368s|.*%{configure}.*|   %{configure} ${BASEFLAGS} ${prec_flags[iprec]} MPIRUN="${ROOT_MPIRUN}" --enable-mpi \\|' fftw.spec
fi

# Time to build!
cd ..
rpmbuild -ba ~/rpmbuild/SPECS/fftw.spec > $build_log
