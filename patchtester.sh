#!/bin/bash

# Variables setup
source ./patchtester.conf

function launch_vm {
	qemu-system-x86_64 \
  -kernel $KERNEL_TREE_PATH/arch/x86/boot/bzImage \
  -append "console=ttyS0 root=/dev/sda debug earlyprintk=serial slub_debug=QUZ" \
  -hda $IMAGE_PATH \
  -net user,hostfwd=tcp::10021-:22 -net nic \
  -enable-kvm \
  -nographic \
  -m 2G \
  -smp 2 \
  -pidfile vm.pid \
  2>&1 &
}

if [ "$KERN_MOD" == "Y" ]; then
	./module.sh
	exit 0
fi

cd $KERNEL_TREE_PATH

# Revert the kernel to the state previous to the patch
git checkout master
git checkout $GIT_CHKSUM_BEFORE_PATCH

# Configure the kernel
rm .config
mv $KERNEL_CONFIG_FILE .
yes "" | make oldconfig

# Compile the kernel
make CC="$GCC_PATH/install/bin/gcc" -j 4

# We have test files; we don't need to fuzz
if [ $CASE -eq 0 ]
then
	launch_vm

	# Wait for the VM to boot
	sleep 10

	# Copy the test files to the VM and launch the test program
	scp -i $SSH_KEY_PATH -P 10021 -o "StrictHostKeyChecking no" $CRASH_PROGRAM_PATH/* root@localhost:~
	ssh -i $SSH_KEY_PATH -p 10021 -o "StrictHostKeyChecking no" root@localhost "~/syz-execprog -executor=~/syz-executor -repeat=0 -procs=16 -cover=0 test.prog"

	# Check the VM for the crash and stop the VM

# We need to fuzz
elif [ $CASE -eq 1 ] || [ $CASE -eq 2 ] 
then
	
	# Run syzkaller
	cd $SYZKALLER_PATH
	mv workdir old_workdirZ
	./bin/syz-manager -config=myconfig.cfg 2&> /dev/null & 

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
else
	echo "Wrong CASE variable in configuration file!"
fi
# Test the patch

# Revert to the patched kernel
cd $KERNEL_TREE_PATH
git checkout $GIT_CHKSUM_AFTER_PATCH

# Configure the kernel
rm .config
mv $KERNEL_CONFIG_FILE .
yes "" | make oldconfig

# Compile the kernel
make CC="$GCC_PATH/install/bin/gcc" -j 4

if [ $CASE -eq 0 ] || [ $CASE -eq 1 ]
then
	launch_vm
	sleep 10

	# Test the program on the patched version
	ssh -i $SSH_KEY_PATH -p 10021 -o "StrictHostKeyChecking no" root@localhost "~/syz-execprog -executor=~/syz-executor -repeat=0 -procs=16 -cover=0 test.prog"

	# Check the vm for the crash and stop it

# We don't have a test program; we need to fuzz
elif [ $CASE -eq 2 ]
then
	# Run syzkaller
	cd $SYZKALLER_PATH
	mv workdir old_workdirZ
	./bin/syz-manager -config=myconfig.cfg 2&> /dev/null & 
	echo -ne "Starting syzkaller\n"

	# Validate the patch (hope for no crash)
	while true
	do
		crash="$(ls ./workdir/crashes/)"
		if [ -n "$crash" ]; then
			cat ./workdir/crashes/*/description
			read -p "Is this the actual bug? (y/n)" answer

			# The crash was produced; shut down syzkaller; bad patch
			if [ "$answer" == "y" ]; then
				sudo kill -9 $(pidof syz-manager)
				break
			fi
		fi

		# Stop the syzkaller if there is no crash after enough time
		read -t 10 -p "[Syzkaller working...] Want to continue fuzzing? (y/n)" quit_answer
		if [ "$quit_answer" == "n" ]; then
			sudo kill -9 $(pidof syz-manager)
			break
		fi
	done
else
	echo "Wrong CASE variable"
fi
fi
