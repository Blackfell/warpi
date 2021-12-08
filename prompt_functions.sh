#!/usr/bin/env bash

# Print out error messages etc. - $1 is the message
function pErr {
	printf "[${colors[RED]}!${colors[DEFAULT]}] - $1\n"
}
function pSucc {
	printf "[${colors[GREEN]}!${colors[DEFAULT]}] - $1\n"
}
function pInf {
	printf "[${colors[BLUE]}+${colors[DEFAULT]}] - $1\n"
}
function pDebug {
	printf "[${colors[RED]}+${colors[DEFAULT]}] - $1\n"
}
function pWarn {
	printf "[${colors[YELLOW]}+${colors[DEFAULT]}] - $1\n"
}
function pLow {
	printf "[${colors[MAGENTA]}-${colors[DEFAULT]}] - $1\n"
}
function pPrompt {
	printf "[${colors[MAGENTA]}\?${colors[DEFAULT]}] - $1"
}
