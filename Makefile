# 通常は弄らない。dkms.conf 或いは下位 Makefile を編集して下さい。

SHELL := /bin/bash

PWD ?= $(shell pwd)
KVER ?= $(shell uname -r)
KDIR := /lib/modules/$(KVER)
KBUILD := $(KDIR)/build
SRCS := $(shell find $(PWD)/drivers -name "*.c")
HDRS := $(shell find $(PWD)/drivers -name "*.h")
IDIR := $(sort $(dir $(HDRS))) $(srctree)/drivers/media/dvb-core $(srctree)/drivers/media/dvb-frontends $(srctree)/drivers/media/tuners
# ldflags-y += -s は使用不可: 中間オブジェクトのシンボルを消すと kernel 6.13+ の
# LD 段階 objtool 検証が "unannotated intra-function call" で失敗する。
# サイズ削減は install ターゲットの strip --strip-debug (INSTALL_MOD_STRIP 相当) で行う。
ccflags-y += -O3 -Os -Wformat=2 -Wall -Werror $(addprefix -I, $(IDIR))
MODS := $(shell . $(PWD)/dkms.conf; echo $${BUILT_MODULE_NAME[*]})
DIRS := $(addprefix $(KDIR), $(shell . $(PWD)/dkms.conf; echo $${DEST_MODULE_LOCATION[*]}))
DIR0 := $(firstword $(DIRS))
DSTS := $(join $(DIRS), $(addprefix /, $(addsuffix *, $(MODS))))
TGTS := $(addsuffix .ko, $(MODS))
obj-m := $(TGTS:.ko=.o)

OBJS := $(join $(shell . $(PWD)/dkms.conf; echo $${DEST_MODULE_LOCATION[*]} | sed "s|/kernel/||g"), $(addprefix /, $(addsuffix .o, $(MODS))))
$(shell echo $(join $(TGTS:.ko=-objs:=), $(OBJS)) | sed "s/ /\n/g" > $(PWD)/m~)
$(foreach OBJ, $(OBJS), $(shell grep -s ccflags-y $(PWD)/$(dir $(OBJ))/Makefile >> $(PWD)/m~))
$(foreach OBJ, $(OBJS), $(shell echo $(patsubst %.o, $(dir $(OBJ))%.o, $(shell grep -s $(notdir $(OBJ:.o=-objs)) $(PWD)/$(dir $(OBJ))/Makefile)) >> $(PWD)/m~))
include $(PWD)/m~

all: $(TGTS)
#	@echo KDIR[$(KDIR)] TGTS[$(TGTS)]
	-@$(RM) -vrf `find /lib/modules -type d -path "*pci/pt3"`
	-@$(RM) -vf `find /lib/modules -type f -name "qm1d1c0042*"`
	$(MAKE) -C $(KBUILD) M=`pwd`
$(TGTS): $(SRCS) $(HDRS)

debug:
	@make "ccflags-y += -DDEBUG $(ccflags-y)"

clean-files := *.o *.ko *.mod.[co] *~
clean-files += $(foreach DIR, $(shell find $(PWD) -type d), $(addprefix $(DIR)/, $(clean-files)))
clean:
	$(MAKE) -C $(KBUILD) M=`pwd` clean
#	-@$(RM) -vf $(foreach TGT, $(TGTS), $(shell find $(KDIR) -name $(TGT)\*))
	@$(RM) -v $(clean-files)

check: clean
	$(KBUILD)/scripts/checkpatch.pl --no-tree --show-types --ignore GCC_BINARY_CONSTANT --max-line-length=200 -f \
		`find \( -iname "*c" -o -iname "*h" \)` | tee warns~
	if [ -f /usr/local/smatch/smatch ] ; then \
		$(MAKE) CHECK="/usr/local/smatch/smatch --full-path" CC=/usr/local/smatch/cgcc |& tee -a warns~; \
	fi

uninstall:
	@$(RM) -vrf $(DSTS)

install: uninstall all
	install -d $(DIR0)
	install -m 644 $(TGTS) $(DIR0)
	cd $(DIR0) && strip --strip-debug $(TGTS)
	depmod -a $(KVER)

install_compress: install
	. $(KBUILD)/.config ; \
	cd $(DIR0); \
	if [ $$CONFIG_DECOMPRESS_XZ = "y" ]; then \
		xz -9e $(TGTS); \
	elif [ $$CONFIG_DECOMPRESS_BZIP2 = "y" ]; then \
		bzip2 -9 $(TGTS); \
	elif [ $$CONFIG_DECOMPRESS_GZIP = "y" ]; then \
		gzip -9 $(TGTS); \
	fi
	depmod -a $(KVER)

# Docker ビルドテスト。TEST_UBUNTU/TEST_KSRC で対象を切替:
#   make test                                (Ubuntu 24.04 / kernel 6.8)
#   make test TEST_UBUNTU=26.04 TEST_KSRC=7.0 (Ubuntu 26.04 / kernel 7.0)
#   make test-all                            (両方)
# コンテナ内では Ubuntu の linux-headers-*-generic (完全な Module.symvers 付き)
# に対してビルドし、全モジュールの .ko 生成を成功条件とする。
TEST_UBUNTU ?= 24.04
TEST_KSRC ?= 6.8

test:
	@echo "=== Testing Docker container build (Ubuntu $(TEST_UBUNTU) / kernel $(TEST_KSRC)) ==="
	@echo "Building Docker image with source code..."
	@docker build --build-arg UBUNTU=$(TEST_UBUNTU) --build-arg KSRC=$(TEST_KSRC) -t ptx-build-test-$(TEST_KSRC) . && \
		echo "Docker build: SUCCESS" || \
		(echo "Docker build: FAILED" && exit 1)
	@echo ""
	@echo "Testing build inside container..."
	@docker run --rm ptx-build-test-$(TEST_KSRC) bash -c '\
		cd /opt/ptx && \
		KB=$$(ls -d /usr/src/linux-headers-*-generic 2>/dev/null | sort -V | tail -1) && \
		if [ -n "$$KB" ]; then KV=$${KB##*linux-headers-}; \
		else KB=/usr/src/linux-$(TEST_KSRC); KV=$(TEST_KSRC).0; fi && \
		echo "Building against $$KB (KVER=$$KV)" && \
		make KVER=$$KV KDIR=$$KB KBUILD=$$KB && \
		for m in $(TGTS); do \
			[ -f $$m ] && echo "OK: $$m" || { echo "MISSING: $$m"; exit 1; }; \
		done' && \
		echo "Container build test: SUCCESS" || \
		(echo "Container build test: FAILED" && exit 1)
	@echo ""
	@echo "=== Docker build test completed successfully ==="

test-all:
	$(MAKE) test
	$(MAKE) test TEST_UBUNTU=26.04 TEST_KSRC=7.0