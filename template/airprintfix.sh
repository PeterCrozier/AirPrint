#!/bin/bash

dns-sd -R "<insert printer name here> airprint" _ipp._tcp,_universal . 631 \
	txtvers='1' \
	pdl='application/pdf,image/urf' \
	URF='none'
