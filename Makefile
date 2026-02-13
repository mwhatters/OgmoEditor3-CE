APP_NAME := Ogmo Editor (Plus)
SRC := dist/mac-arm64/$(APP_NAME).app
DEST := /Applications/$(APP_NAME).app

.PHONY: install

install:
	@echo "Installing $(APP_NAME) to /Applications..."
	rm -rf "$(DEST)"
	cp -R "$(SRC)" "$(DEST)"
	@echo "Done."
