S=@
OPA=opa
CONFIG_FILE=mahjong.conf
LOGS=error.log access.log
BUILD_DIRS=_build _tracks *.opx *.opx.broken
PLUGINS_DIR=plugins
PLUGINS=-I {plugins} engine2d.opp

SRC_DIR=src
SRC_FILES=$(wildcard $(SRC_DIR)/*.opa)

BIN_DIR=bin
EXEC_NAME=./mahjong.exe
RUN_OPTS= --verbose 2 --db-remote:mahjong localhost:27017
DEBUG_NAME=./mahjong.exe --verbose 8
EXEC=$(BIN_DIR)/$(EXEC_NAME)

INSTALL_DIR=/usr/bin/mahjong

default:
	$(S) clear
	$(OPA) $(PLUGINS) $(SRC_FILES) -o $(EXEC)
 
all:
	$(S) clear	
	$(S) make clean
	$(S) make plugin
	$(OPA) $(PLUGINS) $(SRC_FILES) -o $(EXEC)

plugin:
	cd plugins && make clean && make all && cd -	

install:
	$(S) install $(EXEC) $(INSTALL_DIR)

run:
	$(S) cd $(BIN_DIR) && $(EXEC_NAME) $(RUN_OPTS) && cd -

debug:
	$(S) cd $(BIN_DIR) && $(DEBUG_NAME) $(RUN_OPTS) && cd - 

clean:
	$(S) rm -fvr $(BUILD_DIRS)
	$(S) rm -fvr $(BIN_DIR)/*.log
	$(S) rm -fvr $(BIN_DIR)/*.out
	$(S) rm -fvr $(PLUGINS_DIR)/*.opp
	$(S) rm -fvr $(EXEC)
