#!/bin/bash

# Variables setup
source ./patchtester.conf

# Apply kernel module
#cd $KERNEL_TREE_PATH
#cp $MAKEFILE_PATH ./kernel/Makefile
#cp $MODULE_PATH ./kernel/proctest.c

#rm .config
#yes "" | make defconfig
#yes "" | make kvmconfig
#cp $KERNEL_CONFIG_FILE ./.config
#yes "" | make oldconfig
#make CC="$GCC_PATH/install/bin/gcc" -j 4


# Test vulnerable kernel
cd $SYZKALLER_PATH
mv workdir old_workdirZ
mkdir workdir
cd workdir
mkdir crashes
cd ..
./bin/syz-manager -config=conf.cfg 2&> /dev/null &

# Check for the crash
while true
do
	crash="$(ls ./workdir/crashes/)"
        if [ -n "$crash" ]; then
        	cat ./workdir/crashes/*/description
	        read -p "Is this the actual bug? (y/n)" answer

        	# The crash has occured; shut down syzkaller
	        if [ "$answer" == "y" ]; then
        		sudo kill -9 $(pidof syz-manager)
                	break
	        fi
        fi

        sleep 2

done

# Patch kernel

#cd $KERNEL_TREE_PATH
#rm ./kernel/Makefile
#cp $PATCHED_MAKEFILE_PATH ./kernel/Makefile

#rm .config
#cp $KERNEL_CONFIG_FILE ./.config
#yes "" | make oldconfig
#yes "" | make defconfig
#yes "" | make CC="$GCC_PATH/install/bin/gcc" -j 4
 
# Check for the crash
#while true
#do
#	crash="$(ls ./workdir/crashes/)"
        #if [ -n "$crash" ]; then
        #	cat ./workdir/crashes/*/description
	 #       read -p "Is this the actual bug? (y/n)" answer

        	# The crash has occured; shut down syzkaller
	  #      if [ "$answer" == "y" ]; then
        #		sudo kill -9 $(pidof syz-manager)
         #       	break
	  #      fi
       # fi

       # sleep 2

#done


