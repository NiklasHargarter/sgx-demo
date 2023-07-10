#!/bin/sh

/aesmd.sh

gramine-sgx-get-token --output demo.token --sig demo.sig
gramine-sgx demo