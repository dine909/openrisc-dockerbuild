
# LINUX_BRANCH=		v5.2
include patchy.mk
GITS=		ssh://dine@192.168.1.64:/Users/dine/Documents/openriscmerge/linux;b4.9 \
			http://github.com/buildroot/buildroot;master \
			http://github.com/olofk/fusesoc;1.9 \
			https://github.com/stffrdhrn/mor1kx-generic;master \
			https://github.com/openrisc/or1k_marocchino;master


LINUX_DIR=linux

ARCH 		?= openrisc

# LINUX_CONFIG ?= $(BR_CONFIG)
LINUX_CONFIG ?= de0_nano
BR_CONFIG ?= de0_or1k

CPIOGZ ?= output/images/rootfs.cpio.gz
BR_CPIOGZ ?= src/buildroot/$(CPIOGZ)

CROSS_COMPILE_ROOT = output/host/bin/or1k-linux-
CROSS_COMPILE ?= $(shell pwd)/src/buildroot/$(CROSS_COMPILE_ROOT)
CROSS_COMPILE_GCC = $(CROSS_COMPILE)gcc
GCC_TARGET = src/buildroot/$(CROSS_COMPILE_ROOT)gcc


XDG_CONFIG_HOME = src/fusesoc_data
DOWNLOADS_DIR=downloads

FUSESOC_BIN=/usr/local/bin/fusesoc
FUSESOC_CONF=$(XDG_CONFIG_HOME)/fusesoc/fusesoc.conf

BR_CONFIG_FILE=src/buildroot/configs/$(BR_CONFIG)_defconfig
LINUX_CONFIG_FILE=src/$(LINUX_DIR)/arch/openrisc/configs/$(LINUX_CONFIG)_defconfig

WORDHY = $(word $2,$(subst -, ,$1))
WORDAT = $(word $2,$(subst ;, ,$1))
SRCDIR=src/$(notdir $(call WORDAT,$1,1))

GIT_URLS=	 	$(foreach GIT,$(GITS),$(call WORDAT,$(GIT),1))
ALL_SRC_DIRS = 	$(foreach GIT,$(GITS),$(call SRCDIR,$(GIT)))
GIT_OBS=		$(notdir $(GIT_URLS))

GIT_URL=$(filter $(addprefix %/,$(notdir $1)),$(GIT_URLS))
GIT_VER=$(call WORDAT,$(filter $(addsuffix ;%,$(call GIT_URL,$1)),$(GITS)),2)
GIT_DIR=$(notdir $(call GIT_URL,$1))
GIT_SRC_DIR=src/$(notdir $(call GIT_URL,$1))

PATCH_DIR = patches

VMLINUX = vmlinux

SYSNAME=de0_nano_plus
OUTPUT_SOF = build/$(SYSNAME)_0/bld-quartus/$(SYSNAME)_0.sof

.PRECIOUS = $(GCC_TARGET) src/$(LINUX_DIR)/.config src/buildroot/.config $(BR_CPIOGZ) $(FUSESOC_CONF) $(FUSESOC_BIN)
all: 
	echo $(addsuffix -%,$(GIT_OBS))

$(ALL_SRC_DIRS): 
	@mkdir -p $(dir $@)
	git clone -b$(call GIT_VER,$@) --depth=1 $(call GIT_URL,$@) $@ && cd $(call GIT_SRC_DIR,$@) && git checkout $(call GIT_VER,$@) && git tag origin_tag || true
	@$(MAKE) patch-$(call GIT_DIR,$@)

# linux: linux-prepare
# 	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(MAKE) -C src/$@ all

$(GCC_TARGET) $(BR_CPIOGZ): src/buildroot src/buildroot/.config 
	$(MAKE) -C src/buildroot all
	touch $@

source: $(ALL_SRC_DIRS)

clean-downloads:
	rm -rf $(DOWNLOADS_DIR)

clean-all: clean-downloads
	@rm -rf src

reset-all: $(addprefix reset-,$(GIT_OBS))

reset-%: src/%
	@cd src/$(call WORDHY,$@,2) && git reset --hard origin_tag && git clean -dfx && git checkout origin_tag
	@$(MAKE) patch-$(call WORDHY,$@,2)

src/buildroot/.config: 
	@$(MAKE) -C src/buildroot $(BR_CONFIG)_defconfig
	@touch $@

genconfig-buildroot: 
	grep -v ^\# src/buildroot/.config | grep  . > $(BR_CONFIG_FILE)

genconfig-linux: 
	grep -v ^\# src/$(LINUX_DIR)/.config | grep  . > $(LINUX_CONFIG_FILE)


# buildroot-prepare: src/buildroot/.config
	# touch $@

# linux-prepare: src/$(LINUX_DIR)/.config 


src/$(LINUX_DIR)/$(VMLINUX):  src/$(LINUX_DIR)/.config #$(GCC_TARGET) $(BR_CPIOGZ)
	@ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(MAKE) -C src/$(LINUX_DIR) $(VMLINUX)
	@touch $@

# buildroot: $(BR_CPIOGZ)

# $(GCC_TARGET): $(BR_CPIOGZ)
	# touch $@

src/$(LINUX_DIR)/.config:  src/$(LINUX_DIR) $(GCC_TARGET)
	@ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(MAKE) -C src/$(LINUX_DIR) $(LINUX_CONFIG)_defconfig
	@touch $@

qemu-sim: src/$(LINUX_DIR)/$(VMLINUX)
	qemu-system-or1k -cpu or1200 -M or1k-sim -kernel src/$(LINUX_DIR)/$(VMLINUX) -serial stdio -nographic -monitor none

fusesoc-bin: $(FUSESOC_BIN)

$(FUSESOC_BIN): src/fusesoc
	@bash -c "cd src/fusesoc ; pip install -e ."
	# @touch $@

$(FUSESOC_CONF): $(FUSESOC_BIN) src/mor1kx-generic src/or1k_marocchino
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc init -y
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc library add intgen https://github.com/stffrdhrn/intgen.git
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc library add de0_nano_marocchino  $(shell pwd)/systems/de0_nano_marocchino
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc library add de0_nano_plus  $(shell pwd)/systems/de0_nano_plus
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc library add mor1kx-generic  $(shell pwd)/src/mor1kx-generic
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc library add or1k_marocchino $(shell pwd)/src/or1k_marocchino
	@mkdir -p $(dir $@)
	# @touch $@

$(SYSNAME): $(OUTPUT_SOF)

$(OUTPUT_SOF): $(FUSESOC_CONF) 
	@XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) quartus_wrapper fusesoc build $(SYSNAME)

# de0_nano_pgm: build/de0_nano_0/bld-quartus/de0_nano_0.sof
	# @XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) quartus_wrapper fusesoc pgm de0_nano

FIND_PATCHES=$(shell find patches/$(call WORDHY,$1,2) -name *.patch | sort )

patch-%: src/%
	@mkdir -p $(PATCH_DIR)/$(call WORDHY,$@,2)
	cd src/$(call WORDHY,$@,2) && git checkout origin_tag && \
		[ "" != "$(call FIND_PATCHES,$@)" ] &&  git am $(addprefix ../../,$(call FIND_PATCHES,$@)) || echo no patches for $(call WORDHY,$@,2)

genpatches-%:
	@mkdir -p $(PATCH_DIR)/$(call WORDHY,$@,2)
	cd src/$(call WORDHY,$@,2) && git format-patch origin_tag -o ../../$(PATCH_DIR)/$(call WORDHY,$@,2)

buildroot-%: 
	$(MAKE) -C src/buildroot $(call WORDHY,$@,2)

linux-%: 
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(MAKE) -C src/$(LINUX_DIR) $(call WORDHY,$@,2)

fusesoc-exp: 
	export XDG_DATA_HOME=$(XDG_CONFIG_HOME) XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) fusesoc $^

vmlinux.bin: src/$(LINUX_DIR)/$(VMLINUX)
	$(CROSS_COMPILE)objcopy -O binary $< $@

vmlinux.ub: vmlinux.bin
	mkimage \
    -A or1k \
    -C none \
    -T standalone \
    -a 0x00000000 \
    -e 0x00000100 \
    -n 'Linux' \
    -d $< \
    $@

vmlinux.ub.hex: vmlinux.ub
	$(CROSS_COMPILE)objcopy -I binary -O ihex $< $@

$(SYSNAME).jic: vmlinux.ub.hex $(OUTPUT_SOF) $(SYSNAME).cof
	quartus_wrapper quartus_cpf -c $(SYSNAME).cof

program: $(SYSNAME).jic
	quartus_wrapper quartus_pgm -m jtag -o "ip;$<"

# downloads/$(notdir %): $(ALL_DL)
# 	@mkdir -p $(dir $@)
# 	@wget -nc downloads/$(LINUX_DL)
 
# src/$(LINUX_DIR):
# 	@mkdir -p $@
	
# 	@curl -sSL $(LINUX_DL) | tar xz --strip-component=1 -C $@ 

# src/buildroot:
# 	@mkdir -p $@
# 	@echo downloading $@
# 	@curl -sSL $(BUILDROOT_DL) | tar xz --strip-component=1 -C $@ 

# src/done: src/$(LINUX_DIR) src/buildroot
# 	touch $@

# downloads: src/done

# $(ALL_DL_FILES): 
# 	mkdir -p $(DOWNLOADS_DIR)
# 	wget $(ALL_DL)
