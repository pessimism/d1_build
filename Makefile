#
#	Build bootable SDcard image for various Allwinner D1 boardss
#
#	Author: Tim Molteno tim@molteno.net
#
DEVICE=/dev/mmcblk0

all: panel dock

panel:
	sudo rm -rf ./lichee_rv_86/*
	DOCKER_BUILDKIT=1 docker-compose build panel
	docker-compose up panel

dock:
	sudo rm -rf ./lichee_rv_dock/*
	DOCKER_BUILDKIT=1 docker-compose build dock
	docker-compose up dock

lcd:
	sudo rm -rf ./lichee_rv_lcd/*
	DOCKER_BUILDKIT=1 docker-compose build lcd
	docker-compose up lcd

clean:
	sudo rm -rf ./lichee_rv_dock/*
	sudo rm -rf ./lichee_rv_86/*
	DOCKER_BUILDKIT=1 docker-compose build --no-cache
	docker-compose up

serial:
	cu -s 115200 -l /dev/ttyUSB0

prerequisites:
	sudo aptitude install binfmt-support

qemu:
	docker create --name dummy d1_build_dock:latest
	sudo docker cp dummy:/builder/Image.gz ./lichee_rv_dock/
	docker rm -f dummy
	sudo qemu-system-riscv64 -m 1G -nographic -machine virt \
		-kernel ./lichee_rv_dock/Image.gz -append "earlycon=sbi console=ttyS0,115200n8 root=/dev/mmcblk0p2 cma=96M" \
		-drive file=./lichee_rv_dock/lichee_rv_dock_gcc_10.2.1_kernel_d1_all.img,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0
