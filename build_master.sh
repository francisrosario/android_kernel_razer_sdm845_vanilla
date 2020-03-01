#!/bin/bash

VERSION="$(cat version)-$(date +%F | sed s@-@@g)"

./build_kernel.sh stock "$@"
bash ./GenerateChangelog.sh

if [ -e boot.img ] ; then
	rm TrinityKernel-kernel-$VERSION.zip 2>/dev/null
	cp boot.img kernelzip/boot.img
	cp boot.img TrinityKernel-kernel-$VERSION.img
	cd kernelzip/
	7z a -mx0 TrinityKernel-kernel-$VERSION-tmp.zip *
	zipalign -v 4 TrinityKernel-kernel-$VERSION-tmp.zip ../TrinityKernel-kernel-$VERSION.zip
	rm TrinityKernel-kernel-$VERSION-tmp.zip
	cd ..
	ls -al TrinityKernel-kernel-$VERSION.zip
	rm kernelzip/boot.img
fi
