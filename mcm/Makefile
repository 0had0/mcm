# MCM Makefile
# System-wide installation for macOS/Linux

PREFIX ?= /usr/local
SBINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/mcm
SYSCONFDIR ?= /etc/mcm

INSTALL ?= install
RM ?= rm -f
MKDIR ?= mkdir -p
CHMOD ?= chmod

# Installation targets
.PHONY: install uninstall user-install user-uninstall clean help

# System-wide install (requires sudo)
install:
	@echo "Installing MCM to $(SBINDIR)..."
	$(MKDIR) -p $(DESTDIR)$(SBINDIR)
	$(MKDIR) -p $(DESTDIR)$(DATADIR)
	$(MKDIR) -p $(DESTDIR)$(SYSCONFDIR)
	$(INSTALL) -m 755 mcm.sh $(DESTDIR)$(SBINDIR)/mcm
	$(INSTALL) -m 644 ccwrap.sh $(DESTDIR)$(SBINDIR)/ccwrap
	$(INSTALL) -m 644 providers.conf $(DESTDIR)$(DATADIR)/providers.conf
	@echo ""
	@echo "MCM installed to $(SBINDIR)/mcm"
	@echo "Providers installed to $(DATADIR)/providers.conf"
	@echo ""
	@echo "Add to ~/.bashrc or ~/.zshrc:"
	@echo "  export MCM_DIR=$$HOME/.mcm"
	@echo "  export MCM_PROVIDERS=\"$(DATADIR)/providers.conf\""
	@echo "  source $$(which ccwrap.sh)"
	@echo "  alias cc='ccwrap'"

# User install (no sudo required)
user-install:
	@echo "Installing MCM to $$HOME/.local..."
	$(MKDIR) -p $(DESTDIR)$(HOME)/.local/bin
	$(MKDIR) -p $(DESTDIR)$(HOME)/.local/share/mcm
	$(INSTALL) -m 755 mcm.sh $(DESTDIR)$(HOME)/.local/bin/mcm
	$(INSTALL) -m 644 ccwrap.sh $(DESTDIR)$(HOME)/.local/bin/ccwrap
	$(INSTALL) -m 644 providers.conf $(DESTDIR)$(HOME)/.local/share/mcm/providers.conf
	@echo ""
	@echo "MCM installed to $$HOME/.local/bin/"
	@echo ""
	@echo "Add to ~/.bashrc or ~/.zshrc:"
	@echo "  export PATH=\"$$HOME/.local/bin:$$PATH\""
	@echo "  export MCM_DIR=$$HOME/.mcm"
	@echo "  export MCM_PROVIDERS=\"$$HOME/.local/share/mcm/providers.conf\""
	@echo "  source $$HOME/.local/bin/ccwrap"

# System-wide uninstall (requires sudo)
uninstall:
	@echo "Removing MCM..."
	$(RM) $(DESTDIR)$(SBINDIR)/mcm
	$(RM) $(DESTDIR)$(SBINDIR)/ccwrap
	$(RM) -r $(DESTDIR)$(DATADIR)
	@echo "MCM removed from $(SBINDIR)"

# User uninstall
user-uninstall:
	@echo "Removing MCM from $$HOME/.local..."
	$(RM) $(DESTDIR)$(HOME)/.local/bin/mcm
	$(RM) $(DESTDIR)$(HOME)/.local/bin/ccwrap
	$(RM) -r $(DESTDIR)$(HOME)/.local/share/mcm
	@echo "MCM removed from $$HOME/.local"

help:
	@echo "MCM - Multi-Provider Claude Code Manager"
	@echo ""
	@echo "Targets:"
	@echo "  make install        - System-wide install (requires sudo)"
	@echo "  make user-install   - User install (no sudo)"
	@echo "  make uninstall      - Remove system-wide install"
	@echo "  make user-uninstall - Remove user install"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  SBINDIR=$(SBINDIR)"
	@echo "  DATADIR=$(DATADIR)"
	@echo ""
	@echo "Examples:"
	@echo "  sudo make install PREFIX=/opt/mcm"
	@echo "  make install SBINDIR=/usr/bin DATADIR=/usr/share/mcm"
