FROM brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/rhel8:latest
MAINTAINER Courtney Pacheco <cpacheco@redhat.com>
ENV LANG=en_US.utf8

# Flags for building OpenBLAS. Change these for a different build!
ENV OPENBLAS_CFLAGS="-O2 -ftree-vectorize -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fexceptions -fstack-protector-strong -grecord-gcc-switches %{_hardened_cflags} %{_annotated_cflags}"
ENV AVX_FLAGS="NO_AVX=0 NO_AVX2=0 NO_AVX512=1"
ENV TARGET_CPU="TARGET=HASWELL DYNAMIC_ARCH=1"

# Create RHEL 8 repos and update dnf
ENV RHEL8_LATEST /etc/yum.repos.d/rhel80.repo
ENV RHEL8_APPSTREAM /etc/yum.repos.d/rhel8-additional-nightly-appstream.repo
COPY ../../repos/rhel8-Latest.repo ${RHEL8_LATEST}
COPY ../../repos/rhel8-Appstream-Latest.repo ${RHEL8_APPSTREAM}
RUN dnf -y update && \
    /bin/rm -rf /var/cache/dnf*

# Set /usr/bin/python to be python36
RUN ln -s /usr/bin/python /usr/bin/python36

# Install rpmbuild because we will build the package
RUN dnf -y erase yum && \
    dnf -y install automake \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/binutils/2.30/52.el8/x86_64/binutils-2.30-52.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/cpp-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/gcc-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/gcc-c++-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/gcc-gfortran-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/libgcc-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/libgfortran-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/libgomp-8.2.1-3.5.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/gcc/8.2.1/3.5.el8/x86_64/libquadmath-8.2.1-3.5.el8.x86_64.rpm \
                   bc \
                   diffutils \
                   execstack \
                   lapack-static \
                   libtool \
                   make \
                   multilib-rpm-config \
                   patch \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/perl/5.26.3/416.el8/x86_64/perl-Errno-1.28-416.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/perl/5.26.3/416.el8/x86_64/perl-5.26.3-416.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/perl/5.26.3/416.el8/x86_64/perl-devel-5.26.3-416.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/perl/5.26.3/416.el8/x86_64/perl-interpreter-5.26.3-416.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/perl/5.26.3/416.el8/x86_64/perl-libs-5.26.3-416.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpm/4.14.2/7.el8/x86_64/rpm-4.14.2-7.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpm/4.14.2/7.el8/x86_64/rpm-build-4.14.2-7.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpm/4.14.2/7.el8/x86_64/rpm-build-libs-4.14.2-7.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpm/4.14.2/7.el8/x86_64/rpm-libs-4.14.2-7.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpm/4.14.2/7.el8/x86_64/rpm-devel-4.14.2-7.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpm/4.14.2/7.el8/x86_64/python3-rpm-4.14.2-7.el8.x86_64.rpm \
                   http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/rpmdevtools/8.10/7.el8/noarch/rpmdevtools-8.10-7.el8.noarch.rpm \
                   rpmlint \ 
                   time \
                   wget --allowerasing --best && \
    /bin/rm -rf /var/cache/dnf*

# Setup rpmbuild tree
RUN rpmdev-setuptree

# Get OpenBLAS spec file and move to "SPECS" folder under /root/rpmbuild
RUN cd /tmp && \
    wget http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/openblas/0.3.3/2.el8/src/openblas-0.3.3-2.el8.src.rpm && \
    rpm2cpio openblas-0.3.3-2.el8.src.rpm | cpio -civ && \
    mv openblas.spec /root/rpmbuild/SPECS && \
    mv *.patch /root/rpmbuild/SOURCES && \
    rm openblas-0.3.3-2.el8.src.rpm && \
    rm v0.3.3.tar.gz

# Get and apply OpenBLAS patches
RUN cd /root/rpmbuild/SOURCES && \
    wget https://patch-diff.githubusercontent.com/raw/xianyi/OpenBLAS/pull/2010.patch && \
    wget https://patch-diff.githubusercontent.com/raw/xianyi/OpenBLAS/pull/2018.patch && \
    wget https://patch-diff.githubusercontent.com/raw/xianyi/OpenBLAS/pull/2019.patch && \
    wget https://patch-diff.githubusercontent.com/raw/xianyi/OpenBLAS/pull/2021.patch && \
    wget https://patch-diff.githubusercontent.com/raw/xianyi/OpenBLAS/pull/2023.patch && \
    wget https://patch-diff.githubusercontent.com/raw/xianyi/OpenBLAS/pull/2024.patch && \
    dnf -y install git && \
    git config --global user.email "root@podman" && \
    git config --global user.name "root" && \
    git clone https://github.com/xianyi/OpenBLAS.git && \
    cd OpenBLAS && \
    git checkout v0.3.3 && \
    git am ../2010.patch && \
    git am ../2018.patch && \
    git am ../2019.patch && \
    git am ../2021.patch && \
    git am ../2023.patch && \
    git am ../2024.patch && \
    cd .. && \
    mv OpenBLAS OpenBLAS-0.3.3 && \
    tar czvf v0.3.3.tar.gz OpenBLAS-0.3.3 && \
    rm 2010.patch 2018.patch 2019.patch 2021.patch 2023.patch 2024.patch && \
    dnf -y erase git

# Build OpenBLAS with rpmbuild. Note that we must set the "global compiler flags" (i.e., CFLAGS) by editing the macros file.
# We also must set the AVX* flags (NO_AVX, NO_AVX2, and NO_AVX512), the target CPU, and the max number of threads. See top of
# Dockerfile for OPENBLAS_CFLAGS, AVX_FLAGS, and TARGET environment vars. Also note that the 64 bit packages are not built
# because they take up a lot of space and we just want to test the basic, non-64 versions.
RUN N_REAL_CORES=$(lscpu | awk '/^Core\(s\) per socket:/ {cores=$NF}; /^Socket\(s\):/ {sockets=$NF}; END{print cores*sockets}') && \
    cd /root/rpmbuild/SPECS && \
    sed -i "/^%__global_compiler_flags.*/s/^/#/" /usr/lib/rpm/redhat/macros && \
    sed -i "/.*%__global_compiler_flags.*/a %__global_compiler_flags ${OPENBLAS_CFLAGS}" /usr/lib/rpm/redhat/macros && \
    sed -i "352s|TARGET.*|TARGET=\"${TARGET_CPU}\"|" openblas.spec && \
    sed -i "80s|%global build64 1|%global build64 0|" openblas.spec && \
    sed -i "361 i\export AVX=\"${AVX_FLAGS}\"" openblas.spec && \
    sed -i "s|CC=gcc|CC=/usr/bin/x86_64-redhat-linux-gcc|" openblas.spec && \
    sed -i "349s|NMAX=\"NUM_THREADS=128\"|NMAX=\"NUM_THREADS=${N_REAL_CORES}\"|" openblas.spec && \
    cd .. && \
    rpmbuild -ba ~/rpmbuild/SPECS/openblas.spec > openblas_build.log && \
    cd RPMS/x86_64 && \
    dnf -y install * && \
    cd .. && \
    rpmbuild --clean ~/rpmbuild/SPECS/openblas.spec && \
    rm -rf RPMS/x86_64

# Create a folder for the benchmark tests and copy the tests to the new folder
RUN mkdir -p /home/openblas_tests/src
COPY ../src/gemm_test.c /home/openblas_tests/src
COPY ../compile_gemm.sh /home/openblas_tests

# When running the tests, don't forget to use export LD_LIBRARY_PATH=/path/to/openblas-lib-shared-objects
# See README in the main git repo folder for how to compile and run the *gemm tests
