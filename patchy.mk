GITS_PATH = src
GIT_DIRS = $(shell find $(GITS_PATH) -type d -name .git -exec realpath --relative-to=$(GITS_PATH) {}/.. \;)
GIT_NAMES = $(notdir $(GIT_DIRS))

patchy/%: src/$(filter $(notdir $@),$(GIT_NAMES))
	mkdir -p $@

