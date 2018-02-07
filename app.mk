#########################################################################
# common include file for application Makefiles
#
# Makefile Common Usage:
# > make
# > make install
# > make remove
#
# Makefile Less Common Usage:
# > make art-opt
# > make pkg
# > make tr
#
# By default, ZIP_EXCLUDE will exclude -x \*.pkg -x storeassets\* -x keys\* -x .\*
# If you define ZIP_EXCLUDE in your Makefile, it will override the default setting.
#
# To exclude different files from being added to the zipfile during packaging
# include a line like this:ZIP_EXCLUDE= -x keys\*
# that will exclude any file who's name begins with 'keys'
# to exclude using more than one pattern use additional '-x <pattern>' arguments
# ZIP_EXCLUDE= -x \*.pkg -x storeassets\*
#
# Important Notes:
# To use the "install" and "remove" targets to install your
# application directly from the shell, you must do the following:
#
# 1) Make sure that you have the curl command line executable in your path
# 2) Set the variable ROKU_DEV_TARGET in your environment to the IP
#    address of your Roku box. (e.g. export ROKU_DEV_TARGET=192.168.1.1.
#    Set in your this variable in your shell startup (e.g. .bashrc)
##########################################################################
DISTREL = ./out
COMMONREL = ./common
SOURCEREL = .

ZIPREL = $(DISTREL)/apps
PKGREL = $(DISTREL)/packages

APPSOURCEDIR = source
COMPONENTSOURCEDIR = components
IMPORTFILES = $(foreach f,$(IMPORTS),$(COMMONREL)/$f.brs)
IMPORTCLEANUP = $(foreach f,$(IMPORTS),$(APPSOURCEDIR)/$f.brs)

SOURCES := $(shell find $(APPSOURCEDIR) -name '*.brs')
COMPONENTS := $(shell find $(COMPONENTSOURCEDIR) -name '*.brs')
# KKI, add for wist
WISTDIR := wistoutput
MKDIR = mkdir -
# dangerous and simplistic assumption that all file names are unique
WIST_SOURCE_RESULTS = $(WISTDIR)/wist.source.results
WIST_COMPONENT_RESULTS = $(WISTDIR)/wist.component.results
WISTOBJS = $(patsubst %.brs, $(WISTDIR)/%.wist, $(notdir $(SOURCES)))
WISTOBJS += $(patsubst %.brs, $(WISTDIR)/%.wist, $(notdir $(COMPONENTS)))

ifdef DEVPASSWORD
    USERPASS = rokudev:$(DEVPASSWORD)
else
    USERPASS = $(ROKU_DEV_PASSWORD)
endif

BASE_EXCLUDES= -x app.mk -x out/\* \.\* debug\*.sh README.md foo.\* images/publish\*

ifndef INCLUDE_INTRO
    ZIP_EXCLUDE= $(BASE_EXCLUDES) videos/intro.mov
else
    ZIP_EXCLUDE= $(BASE_EXCLUDES)
endif


HTTPSTATUS = $(shell curl --silent --write-out "\n%{http_code}\n" $(ROKU_DEV_TARGET))
HTTPSTATUS2 = $(shell curl --silent --write-out "\n%{http_code}\n" $(ROKU_DEV2_TARGET))
DEPRECATED = $(shell grep -rf deprecated.txt source/ components/| wc -l| tr -d ' ')
OUTPUT_SIZE = $(shell find $(ZIPREL)/$(APPNAME).zip -a -size +1M| wc -l| tr -d ' ')
GIT_STATUS = $(shell git status --porcelain| wc -l| tr -d ' ')

.PHONY: all $(APPNAME) $(DEV_TARGET)

$(APPNAME): manifest
	@echo "*** Creating $(APPNAME).zip ***"

	@echo "  >> removing old application zip $(ZIPREL)/$(APPNAME).zip"
	@if [ -e "$(ZIPREL)/$(APPNAME).zip" ]; \
	then \
		rm  $(ZIPREL)/$(APPNAME).zip; \
	fi

	@echo "  >> creating destination directory $(ZIPREL)"
	@if [ ! -d $(ZIPREL) ]; \
	then \
		mkdir -p $(ZIPREL); \
	fi

	@echo "  >> setting directory permissions for $(ZIPREL)"
	@if [ ! -w $(ZIPREL) ]; \
	then \
		chmod 755 $(ZIPREL); \
	fi

	@echo "  >> copying imports"
	@if [ "$(IMPORTFILES)" ]; \
	then \
		mkdir $(APPSOURCEDIR)/common; \
		cp -f --preserve=ownership,timestamps --no-preserve=mode -v $(IMPORTFILES) $(APPSOURCEDIR)/common/; \
	fi \

# zip .png files without compression
# do not zip up Makefiles, or any files ending with '~'
	@echo "  >> creating application zip $(ZIPREL)/$(APPNAME).zip"
	@if [ -d $(SOURCEREL) ]; \
	then \
		(zip -0 -r "$(ZIPREL)/$(APPNAME).zip" . -i \*.png $(ZIP_EXCLUDE)); \
		(zip -9 -r "$(ZIPREL)/$(APPNAME).zip" . -x \*~ -x \*.png -x Makefile $(ZIP_EXCLUDE)); \
	else \
		echo "Source for $(APPNAME) not found at $(SOURCEREL)"; \
	fi

	@if [ "$(IMPORTCLEANUP)" ]; \
	then \
		echo "  >> deleting imports";\
		rm -r -f $(APPSOURCEDIR)/common; \
	fi \

	@echo "*** packaging $(APPNAME) complete ***"

#if DISTDIR is not empty then copy the zip package to the DISTDIR.
	@if [ $(DISTDIR) ];\
	then \
		rm -f $(DISTDIR)/$(DISTZIP).zip; \
		mkdir -p $(DISTDIR); \
		cp -f --preserve=ownership,timestamps --no-preserve=mode $(ZIPREL)/$(APPNAME).zip $(DISTDIR)/$(DISTZIP).zip; \
	fi \



check:
	@echo "*** Checking for Deprecated items in $(APPNAME) ***"
	@if [ "$(DEPRECATED)" != "0" ]; \
	then \
		echo "  >> Deprecated items found in $(APPNAME): $(DEPRECATED)"; \
		exit 1; \
	fi
	@echo "No deprecated items found in $(APPNAME)"

	@echo "  >> Checking size of $(ZIPREL)/$(APPNAME).zip"
	@if [ "$(OUTPUT_SIZE)" != "0"  ] ; \
	then \
		echo "  >> Zipfile is unusually large. Please check contents."; \
		exit 1; \
	else \
		echo "  >> Zipfile size is ok"; \
	fi

# wist patterns
$(WISTDIR):
	@echo "Making WISTDIR: ${WISTDIR}"
	@-$(MKDIR) $@

# for now brute force, if we detect any newer source, we will wist everything
$(WIST_SOURCE_RESULTS): $(SOURCES)
	@echo "We are at the wist sources check"
	# remove wist.source.results
	-rm -f $(WIST_SOURCE_RESULTS)
	# wisting sources
	-wist $(SOURCES) > $(WIST_SOURCE_RESULTS)
	@if [ -f $(WIST_SOURCE_RESULTS) ] && [ -s $(WIST_SOURCE_RESULTS) ] ; \
	then \
		echo " >> wist found errors, see $(WIST_SOURCE_RESULTS)"; \
	else \
		echo "wist source lint is clean"; \
	fi

$(WIST_COMPONENT_RESULTS): $(COMPONENTS)
	@echo "We are at the wist component check"
	# remove wist.component.results
	-rm -f $(WIST_COMPONENT_RESULTS)
	# wisting components
	-wist $(COMPONENTS) > $(WIST_COMPONENT_RESULTS)
	@if [ -f $(WIST_COMPONENT_RESULTS) ] && [ -s $(WIST_COMPONENT_RESULTS) ] ; \
	then \
		echo " >> wist found errors, see $(WIST_COMPONENT_RESULTS)"; \
	else \
		echo "wist component lint is clean"; \
	fi

wist: $(WISTDIR) $(WIST_SOURCE_RESULTS) $(WIST_COMPONENT_RESULTS)

clean:
	rm -f $(WISTDIR)/*

inst: $(APPNAME) check $(DEV_TARGET)
	@echo "Installing $(APPNAME) to host $(DEV_TARGET)"
	curl -d '' http://$(DEV_TARGET):8060/keypress/home >/dev/null 2>&1
	@if [ "$(HTTPSTATUS)" == " 401" ]; \
	then \
		curl --user $(USERPASS) --digest -s -S -F "mysubmit=Install" -F "archive=@$(ZIPREL)/$(APPNAME).zip" -F "passwd=" http://$(DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[[" ; \
	else \
		curl -s -S -F "mysubmit=Install" -F "archive=@$(ZIPREL)/$(APPNAME).zip" -F "passwd=" http://$(DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[[" ; \
	fi

install:
	$(MAKE) inst $(APPNAME) DEV_TARGET=$(ROKU_DEV_TARGET)

install2:
	$(MAKE) inst APPNAME=$(APPNAME) DEV_TARGET=$(ROKU_DEV2_TARGET)

install3:
	$(MAKE) inst APPNAME=$(APPNAME) DEV_TARGET=$(ROKU_DEV3_TARGET)

bump_version:
	@echo "  >> bumping version number"
	@if [ "$(GIT_STATUS)" != "0"  ] ; \
	then \
		echo "  >> Git is not clean, commit changes first."; \
		exit 1; \
	fi
	perl -i -pe 's/build_version=\K(\d+)/$$1+1/e' manifest
	git commit -m "Build version bump" manifest
	git push

tag:
	./tag_version.sh

production:
	@echo "  >> setting production URLs"
	sed -i "" 's/    return "stage"/    return "production"/' source/util.brs

staging:
	@echo "  >> setting staging URLs"
	sed -i "" 's/    return "production"/    return "stage"/' source/util.brs

package: production install
	$(MAKE) pkg PACKAGE_TARGET=$(ROKU_DEV_TARGET)
package2: production install2
	$(MAKE) pkg PACKAGE_TARGET=$(ROKU_DEV2_TARGET)
package3: production install3
	$(MAKE) pkg PACKAGE_TARGET=$(ROKU_DEV3_TARGET)

pkg:
	@echo "*** Creating Package on host $(PACKAGE_TARGET) ***"

	@echo "  >> creating destination directory $(PKGREL)"
	@if [ ! -d $(PKGREL) ]; \
	then \
		mkdir -p $(PKGREL); \
	fi

	@echo "  >> setting directory permissions for $(PKGREL)"
	@if [ ! -w $(PKGREL) ]; \
	then \
		chmod 755 $(PKGREL); \
	fi

	@echo "  >> removing old packages in $(PKGREL)"
	rm $(PKGREL)/*

	@echo "Packaging  $(APPSRC)/$(APPNAME) on host $(PACKAGE_TARGET)"
	read -p "Password: " REPLY ; echo $$REPLY | curl --user $(USERPASS) --digest -s -S -Fmysubmit=Package -Fapp_name=$(APPNAME)/$(VERSION) -Fpasswd=$$REPLY -Fpkg_time=`expr \`date +%s\` \* 1000` "http://$(PACKAGE_TARGET)/plugin_package"  | grep '<a href="pkgs' | sed 's/.*href=\"\([^\"]*\)\".*/\1/' | sed 's#pkgs//##' | xargs -I{} curl --user $(USERPASS) --digest -s -S -o $(PKGREL)/$(APPNAME)_{} http://$(PACKAGE_TARGET)/pkgs/{}

	@echo "*** Package  $(APPNAME) complete ***"

remove:
	@echo "Removing $(APPNAME) from host $(ROKU_DEV_TARGET)"
	@if [ "$(HTTPSTATUS)" == " 401" ]; \
	then \
		curl --user $(USERPASS) --digest -s -S -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[[" ; \
	else \
		curl -s -S -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[[" ; \
	fi
