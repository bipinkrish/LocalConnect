#! /bin/sh

chmod 777 LocalConnect

# detect machine's architecture
export ARCH=$(uname -m)

# get the missing tools if necessary
if [ ! -d ../build ]; then mkdir ../build; fi
if [ ! -x ../build/appimagetool-$ARCH.AppImage ]; then
  curl -L -o ../build/appimagetool-$ARCH.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$ARCH.AppImage
  chmod a+x ../build/appimagetool-$ARCH.AppImage 
fi
# the build command itself:
../build/appimagetool-$ARCH.AppImage .

mv *.AppImage LocalConnect.AppImage
mv LocalConnect.AppImage ../

cd ..
echo "AppImage created in "
pwd
echo "Done."