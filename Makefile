SHELL := /bin/bash

.SUFFIXES:
.PHONY: all bundle_src bundle_zip clean docs install uninstall

include Makefile.config


### Filename definitions, can be overridden in Makefile.config
# REPO_NAME and BASE_FILENAME should almost always be overridden
REPO_NAME ?= $(notdir $(shell pwd))
BASE_FILENAME ?= $(REPO_NAME)

CUSTOM_TAGS ?= custom_tags.txt
DEFAULT_LANG ?= english.lng
DOC_FILES ?= docs/readme.txt docs/license.txt docs/changelog.txt
GRF_FILE ?= $(BASE_FILENAME).grf
LANG_DIR ?= lang
NML_FILE ?= $(BASE_FILENAME).nml
PNML_FILE ?= $(BASE_FILENAME).pnml

DEFAULT_LANG_FILE := $(LANG_DIR)/$(DEFAULT_LANG)
# Touch all intermediate doc files to force rebuilding
# this and the doc definitions need to be better (define dir?)
$(shell touch docs/*.ptxt)

# Replacement strings which are added to custom.tags and replaced in
# the .txt files output from .ptxt
# These need to be enclosed in double brakets in .ptxt files
REPLACE_GRF_FILENAME := GRF_FILENAME
REPLACE_GRF_VERSION := GRF_VERSION
REPLACE_GRF_TITLE := GRF_TITLE
REPLACE_REPO_VERSION := REPO_VERSION


### Program definitions
CC ?= cc
CC_FLAGS ?= -C -E -nostdinc -x c-header
HG ?= hg


### Info from findversion
VERSION_INFO := "$(shell ./findversion.sh)"
# The version reported to OpenTTD. Usually days since 2000 + branch offset
GRF_VERSION := $(shell echo $(VERSION_INFO) | cut -f2)
# Whether there are local changes
REPO_MODIFIED := $(shell echo $(VERSION_INFO) | cut -f3)
# Any tag which is not 'tip'
REPO_TAGS := $(shell echo $(VERSION_INFO) | cut -f4 | sed 's/ /\\ /g')
# The shown version is either a tag, or in the absence of a tag the revision.
REPO_VERSION := $(shell echo $(VERSION_INFO) | cut -f5)
USED_VCS := $(shell echo $(VERSION_INFO) | cut -f8)
# The title consists of name and version
ifeq ($(REPO_TAGS),)
FILE_VERSION_STRING := $(GRF_VERSION)$(REPO_MODIFIED)
else
FILE_VERSION_STRING := $(REPO_TAGS)$(REPO_MODIFIED)
endif
TAR_STEM := $(BASE_FILENAME)
TAR_FILE := $(TAR_STEM)-$(FILE_VERSION_STRING).tar
TAR_SRC_FILE := $(TAR_STEM)-$(FILE_VERSION_STRING)-source.tar
ZIP_FILE := $(TAR_STEM)-$(FILE_VERSION_STRING).zip
NML_DEP := $(NML_FILE).dep  # .pnml files required for .nml
GRF_DEP := $(GRF_FILE).dep  # Graphics files required for .grf


### Targets called from command line
all: $(GRF_FILE)

ifneq ($(MAKECMDGOALS), clean)
ifneq ($(MAKECMDGOALS), docs)
include $(NML_DEP)
endif
endif
-include Makefile.in

bundle_src: $(TAR_SRC_FILE)

bundle_tar: $(TAR_FILE)

bundle_zip: $(ZIP_FILE)

clean::
	rm -rf $(GRF_FILE) $(NML_FILE) $(NML_DEP) $(GRF_DEP) $(CUSTOM_TAGS) \
               $(TAR_STEM)*.{tar,zip}

docs: $(DOC_FILES)

ifeq ($(shell uname -s), Linux)
ifndef DESTDIR
DESTDIR := $(HOME)/.openttd/newgrf
endif
install: $(TAR_FILE) uninstall
	cp $(TAR_FILE) $(DESTDIR)
uninstall:
	rm -f $(DESTDIR)/$(TAR_STEM)*.tar
else
install uninstall:
	@echo "Error: Only Linux install supported."
	@false
endif


### Other targets called by other rules and includes
# Including grf depencies in nml depencies is a bit hacky, but required
# for make to make two passes and correctly generate grf deps
$(NML_DEP): $(PNML_FILE)
	$(CC) $(CC_FLAGS) -M $(PNML_FILE) -MF $@ -MG -MT $(NML_FILE)
	echo "include $(GRF_DEP)" >> $@

$(NML_FILE):
	$(CC) -D GRF_VERSION=$(GRF_VERSION) $(CC_FLAGS) -o $@ $(PNML_FILE)

$(GRF_DEP) $(GRF_FILE): $(NML_FILE) $(CUSTOM_TAGS) $(LANG_DIR)/$(DEFAULT_LANG)

$(GRF_DEP):
	$(NML) --default-lang=$(DEFAULT_LANG) --lang-dir=$(LANG_DIR) \
               -M --MF=$@ --MT=$(GRF_FILE) --quiet $(NML_FILE)

$(GRF_FILE):
	$(NML) -c --default-lang=$(DEFAULT_LANG) --lang-dir=$(LANG_DIR) \
               --grf $@ $(NML_FILE) --p DEFAULT

$(TAR_FILE): $(GRF_FILE) $(DOC_FILES)
	tar -cf $(TAR_FILE) $^

$(ZIP_FILE): $(TAR_FILE)
	zip -9 $(ZIP_FILE) $(TAR_FILE)

$(TAR_SRC_FILE):
ifeq ($(USED_VCS), hg)
	HGPLAIN= hg archive -X .devzone -t tar $@
else ifeq ($(USED_VCS), git)
	git archive -o $@ HEAD
else
	@echo "Unknown version control system, can't build source package."
	@false
endif

# Attempt to build missing .txt files from .ptxt
%.txt: %.ptxt
	cp $< $@
	sed -e "s/{{$(REPLACE_GRF_FILENAME)}}/$(GRF_FILE)/" -i $@
	sed -e "s/{{$(REPLACE_GRF_TITLE)}}/$(REPO_NAME)/" -i $@
	sed -e "s/{{$(REPLACE_GRF_VERSION)}}/$(GRF_VERSION)/" -i $@
	sed -e "s/{{$(REPLACE_REPO_VERSION)}}/$(REPO_VERSION)/" -i $@

$(CUSTOM_TAGS):
	> $@
	echo "$(REPLACE_GRF_FILENAME) :$(GRF_FILE)" >> $@
	echo "$(REPLACE_GRF_TITLE) :$(REPO_NAME)" >> $@
	echo "$(REPLACE_GRF_VERSION) :$(GRF_VERSION)" >> $@
	echo "$(REPLACE_REPO_VERSION) :$(REPO_VERSION)" >> $@
