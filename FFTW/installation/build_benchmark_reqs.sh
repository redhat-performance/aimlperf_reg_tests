#!/bin/bash

# Builds the benchmark requirements (i.e., libjpeg and ImageMagick)

# The latest libjpeg source has Windows line endings (return carriage), so we'll need to 
# temporarily install dos2unix to convert the line endings to Linux/Unix line endings
dnf -y install unzip dos2unix

# Libjpeg requires a "man1" folder for the manual. (Not sure why it has to be "man1", but
# it is what it is.)
mkdir -p /usr/man/man1

# Change to the /tmp directory so that we're not messing up any folder
cd /tmp

# Get libjpeg
wget https://downloads.sourceforge.net/project/libjpeg/libjpeg/6b/jpegsr6.zip
unzip jpegsr6.zip
cd jpeg-6b

# The 'config.sub' that comes with libjpeg is outdated. It does not recognize modern CPUs.
# We need to get the latest config.sub file.
rm config.sub
wget -c "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
mv 'index.html?p=config.git;a=blob_plain;f=config.sub;hb=HEAD' config.sub
chmod u+x config.sub

# Convert line endings from Windows to Linux
for f in ./*; do dos2unix $f; done

# Configure and install libjpeg
./configure --prefix=/usr --enable-static --enable-shared
make
make install

# Clean up /tmp
cd ..
rm -rf jpeg-6b
rm jpegsr6.zip

# Get the latest ImageMagick
wget https://imagemagick.org/download/ImageMagick.tar.gz
tar xvf ImageMagick.tar.gz
cd ImageMagick-7.0.8-34

# Configure and install
./configure
make
make install

# Clean up /tmp
cd ..
rm ImageMagick.tar.gz
rm -rf ImageMagick-7.0.8-34
dnf -y erase dos2unix

# Clean dnf cache
rm -rf /var/cache/dnf*
